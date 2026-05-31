# Byte-stream-over-frames adapter that turns a frame-oriented `HTTP.WebSocket`
# into an `IO` consumers (Malt's `serve_io`, a wire protocol's `read_frame`,
# librsync's drive loop, etc.) can use directly. Lives in Bonito because
# Bonito already pulls in HTTP for its own websocket handler — keeping the
# adapter here means downstream callers (BonitoMCP eval-worker dial-back,
# BonitoTeam server, RemoteSync) don't have to either redeclare it or take a
# separate dep on RemoteSync for one type.
#
# Stays parametric on `WS` so callers can plug in any frame transport that
# implements `send_frame!`/`recv_frame`/`is_closed`; HTTP.WebSockets bindings
# follow below.

using HTTP, HTTP.WebSockets

mutable struct WebSocketIO{WS} <: IO
    ws        :: WS
    inbuf     :: Vector{UInt8}        # bytes from the last received frame
    inpos     :: Int                  # next byte of inbuf to deliver (1-based)
    outbuf    :: IOBuffer             # accumulates writes until `flush`
    closed    :: Bool
    eof_seen  :: Bool                 # true once the peer has closed
    wlock     :: ReentrantLock        # serializes concurrent multi-write messages
end

WebSocketIO(ws) = WebSocketIO{typeof(ws)}(ws, UInt8[], 1, IOBuffer(), false, false, ReentrantLock())

# Transport surface: receive the next frame (returns `nothing` on close),
# send one frame, and report whether the underlying transport is closed.
# Generic stubs for non-HTTP transports; HTTP.WebSocket impls follow.
function recv_frame end
function send_frame! end
function is_closed end

function recv_frame(ws::HTTP.WebSockets.WebSocket)
    try
        HTTP.WebSockets.isclosed(ws) && return nothing
        frame = HTTP.WebSockets.receive(ws)
        return frame isa AbstractVector{UInt8} ?
            Vector{UInt8}(frame) :
            Vector{UInt8}(codeunits(String(frame)))
    catch e
        e isa HTTP.WebSockets.WebSocketError && return nothing
        e isa Base.IOError                   && return nothing
        e isa EOFError                       && return nothing
        rethrow()
    end
end

function send_frame!(ws::HTTP.WebSockets.WebSocket, bytes::AbstractVector{UInt8})
    HTTP.WebSockets.send(ws, bytes)
    return nothing
end

is_closed(ws::HTTP.WebSockets.WebSocket) = HTTP.WebSockets.isclosed(ws)

# ── IO interface ───────────────────────────────────────────────────────────
function _refill!(io::WebSocketIO)
    io.eof_seen && return false
    frame = recv_frame(io.ws)
    if frame === nothing
        io.eof_seen = true
        return false
    end
    io.inbuf = frame
    io.inpos = 1
    return true
end

function Base.eof(io::WebSocketIO)
    io.inpos <= length(io.inbuf) && return false
    return !_refill!(io)
end

Base.isopen(io::WebSocketIO) = !io.closed && !is_closed(io.ws)

function Base.close(io::WebSocketIO)
    io.closed && return
    io.closed = true
    try
        # `position` rather than `bytesavailable`: after a series of writes,
        # `bytesavailable(IOBuffer)` returns 0 (it counts unread bytes from
        # the current position, not the total writes pending).
        position(io.outbuf) > 0 && send_frame!(io.ws, take!(io.outbuf))
    catch
    end
    return nothing
end

function Base.read(io::WebSocketIO, ::Type{UInt8})
    while io.inpos > length(io.inbuf)
        _refill!(io) || throw(EOFError())
    end
    b = io.inbuf[io.inpos]
    io.inpos += 1
    return b
end

function Base.readbytes!(io::WebSocketIO, dst::Vector{UInt8}, n = length(dst))
    n = Int(n)
    n > length(dst) && resize!(dst, n)
    written = 0
    while written < n
        avail = length(io.inbuf) - io.inpos + 1
        if avail == 0
            _refill!(io) || break
            avail = length(io.inbuf) - io.inpos + 1
            avail == 0 && break
        end
        take = min(avail, n - written)
        @inbounds copyto!(dst, written + 1, io.inbuf, io.inpos, take)
        io.inpos += take
        written  += take
    end
    return written
end

# Read exactly `n` bytes or throw EOFError. Matches `Base.read(io, n)` shape
# used by Malt's wire protocol's read_frame.
function Base.read(io::WebSocketIO, n::Integer)
    n = Int(n)
    out = Vector{UInt8}(undef, n)
    got = readbytes!(io, out, n)
    got == n || throw(EOFError())
    return out
end

# Buffered writes: callers like Malt's `_serialize_msg` make many small writes
# during one logical message. Coalesce them into one WS frame per `flush`.
Base.write(io::WebSocketIO, b::UInt8) = (write(io.outbuf, b); 1)
Base.unsafe_write(io::WebSocketIO, p::Ptr{UInt8}, n::UInt) = UInt(unsafe_write(io.outbuf, p, n))

function Base.flush(io::WebSocketIO)
    # See note in `close` — must use `position`, not `bytesavailable`.
    position(io.outbuf) == 0 && return nothing
    send_frame!(io.ws, take!(io.outbuf))
    return nothing
end

# Read exactly `n` bytes into `p`, refilling frames as needed (or throw EOFError).
# Needed by `Serialization.deserialize` and `read(io, ::Type{T})` for bitstypes
# (e.g. the UInt64 message id in Malt's wire protocol).
function Base.unsafe_read(io::WebSocketIO, p::Ptr{UInt8}, n::UInt)
    nr = 0
    while nr < n
        if io.inpos > length(io.inbuf)
            _refill!(io) || throw(EOFError())
        end
        avail = length(io.inbuf) - io.inpos + 1
        take = min(avail, Int(n) - nr)
        GC.@preserve io unsafe_copyto!(p + nr, pointer(io.inbuf, io.inpos), take)
        io.inpos += take
        nr += take
    end
    return nothing
end

# Lock so concurrent multi-`write` messages don't interleave into `outbuf`.
Base.lock(io::WebSocketIO)    = lock(io.wlock)
Base.unlock(io::WebSocketIO)  = unlock(io.wlock)
Base.trylock(io::WebSocketIO) = trylock(io.wlock)

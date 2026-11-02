// Normal events use receiver capacity. Protocol results never enter this window.
export class MessageWindow {
    constructor({ capacity, limit, encode, send }) {
        if (!Number.isSafeInteger(capacity) || capacity < 1 || !Number.isSafeInteger(limit) || limit < capacity) {
            throw new RangeError("Invalid message window capacity");
        }
        this.capacity = capacity;
        this.limit = limit;
        this.encode = encode;
        this.send = send;
        this.pending = [];
        this.head = 0;
        this.history = new Map();
        this.assigned = 0;
        this.sent = 0;
        this.received = 0;
        this.released = 0;
        this.connected = false;
        this.flushing = false;
    }

    get backlog() { return this.pending.length - this.head + this.history.size; }

    enqueue(message) {
        if (this.backlog >= this.limit) throw new Error("Message backlog capacity exceeded");
        const sequence = this.assigned + 1;
        const packet = this.encode(message, sequence);
        this.assigned = sequence;
        this.pending.push({ sequence, packet });
        this.flush();
    }

    disconnect() { this.connected = false; }

    update(received, released) {
        if (!Number.isSafeInteger(received) || !Number.isSafeInteger(released) ||
            released < 0 || received < released || received > this.sent) {
            throw new Error("Invalid message credit");
        }
        this.received = Math.max(this.received, received);
        this.released = Math.max(this.released, released);
        for (const sequence of this.history.keys()) {
            if (sequence > this.received) break;
            this.history.delete(sequence);
        }
    }

    ack(received, released) {
        this.update(received, released);
        this.flush();
    }

    resume(received, released) {
        if (received < this.received || released < this.released) {
            throw new Error("Receiver lost message window state");
        }
        this.update(received, released);
        this.connected = true;
        // Replay keeps identities; the receiver can discard duplicates.
        for (const packet of this.history.values()) {
            if (!this.transmit(packet)) return;
        }
        this.flush();
    }

    transmit(packet) {
        let accepted;
        try {
            accepted = this.send(packet);
        } catch (error) {
            this.connected = false;
            throw error;
        }
        if (accepted !== true) {
            this.connected = false;
            return false;
        }
        return true;
    }

    flush() {
        if (!this.connected || this.flushing) return;
        this.flushing = true;
        try {
            while (this.connected && this.head < this.pending.length &&
                this.sent - this.released < this.capacity) {
                const { sequence, packet } = this.pending[this.head++];
                this.sent = sequence;
                this.history.set(sequence, packet);
                if (!this.transmit(packet)) break;
            }
            if (this.head > 0 && this.head * 2 >= this.pending.length) {
                this.pending = this.pending.slice(this.head);
                this.head = 0;
            }
        } finally {
            this.flushing = false;
        }
    }
}

export class MessageWindows {
    constructor({ encode, send, query, snapshot = structuredClone }) {
        this.encode = encode;
        this.send = send;
        this.query = query;
        this.snapshot = snapshot;
        this.unconfigured = [];
        this.windows = new Map();
        this.aliases = new Map();
        this.defaultOwner = null;
        this.connected = false;
    }

    configure(info) {
        let window = this.windows.get(info.owner);
        if (!window) {
            window = new MessageWindow({ capacity: info.capacity, limit: Math.max(4096,info.capacity),
                encode: (message, sequence) => this.encode({ ...message, flow_owner: info.owner, event_sequence: sequence }),
                send: packet => this.send(packet),
            });
            this.windows.set(info.owner,window);
        } else if (window.capacity !== info.capacity) {
            throw new Error("Receiver changed message window capacity");
        }
        this.aliases.set(info.alias,info.owner);
        if (info.default) this.defaultOwner = info.owner;
        const waiting = this.unconfigured;
        this.unconfigured = [];
        for (const message of waiting) {
            const target = this.windowFor(message);
            if (target) target.enqueue(message);
            else this.unconfigured.push(message);
        }
        if (info.resume && this.connected) {
            const wasPaused = !window.connected;
            if (wasPaused) window.resume(info.received,info.released);
            else window.ack(info.received,info.released);
            if (wasPaused && info.default) this.queryPaused();
        } else if (this.connected && !window.connected) {
            this.query(info.owner);
        }
    }

    queryPaused() {
        for (const [owner,window] of this.windows) {
            if (!window.connected) this.query(owner);
        }
    }

    open() {
        this.connected = true;
        for (const window of this.windows.values()) window.disconnect();
        this.queryPaused();
    }

    disconnect() {
        this.connected = false;
        for (const window of this.windows.values()) window.disconnect();
    }

    credit(info) {
        this.windows.get(info.owner)?.ack(info.received,info.released);
    }

    forget(owner) {
        this.windows.delete(owner);
        for (const [alias,target] of this.aliases) {
            if (target===owner) this.aliases.delete(alias);
        }
        if (this.defaultOwner===owner) this.defaultOwner=null;
    }

    windowFor(message) {
        let owner = this.defaultOwner;
        let longest = 0;
        const id = message.id;
        if (typeof id === "string") {
            if (id.includes("/")) owner = null;
            for (const [alias,target] of this.aliases) {
                if (alias.length > longest && (id===alias || id.startsWith(alias+"/"))) {
                    owner=target;
                    longest=alias.length;
                }
            }
        }
        return this.windows.get(owner);
    }

    enqueue(message) {
        const window = this.windowFor(message);
        if (window) window.enqueue(message);
        else {
            if (this.unconfigured.length >= 4096) throw new Error("Uninitialized message backlog capacity exceeded");
            this.unconfigured.push(this.snapshot(message));
        }
    }
}

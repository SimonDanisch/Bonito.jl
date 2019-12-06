const CSPRNG = Random.RandomDevice()

function salt()
    return string(rand(CSPRNG, UInt64))
end

function encrypt(password::String, s = salt())
    pw = SHA.sha256(s, password)
    return s, pw
end

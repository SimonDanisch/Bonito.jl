using Test
using Bonito
using Bonito: pbkdf2_simple, generate_salt, User, SingleUser, ProtectedRoute
using Bonito: authenticate, get_user, check_auth, FolderServer
using Base64
using Dates

# Define LoggingHandler
struct LoggingHandler{T}
    handler::T
    log_file::String
end

function Bonito.HTTPServer.apply_handler(logger::LoggingHandler, context)
    request = context.request
    # Log the request
    open(logger.log_file, "a") do io
        println(io, "$(Dates.now()): $(request.method) $(request.target)")
    end
    # Delegate to wrapped handler
    return Bonito.HTTPServer.apply_handler(logger.handler, context)
end

@testset "Protected Route" begin
    @testset "PBKDF2 Basic Functionality" begin
        password = "test_password"
        salt = generate_salt(16)

        # Test that PBKDF2 produces consistent results
        hash1 = pbkdf2_simple(password, salt; iterations=100)
        hash2 = pbkdf2_simple(password, salt; iterations=100)
        @test hash1 == hash2

        # Test that different salts produce different hashes
        salt2 = generate_salt(16)
        hash3 = pbkdf2_simple(password, salt2; iterations=100)
        @test hash1 != hash3

        # Test that output is 32 bytes (SHA256)
        @test length(hash1) == 32
    end

    @testset "Salt Generation" begin
        salt1 = generate_salt(16)
        salt2 = generate_salt(16)

        @test length(salt1) == 16
        @test length(salt2) == 16
        @test salt1 != salt2  # Should be random

        # Test different lengths
        salt_small = generate_salt(8)
        salt_large = generate_salt(32)
        @test length(salt_small) == 8
        @test length(salt_large) == 32
    end

    @testset "User Creation and Authentication" begin
        # Create user with password
        user = User("alice", "secret123"; iterations=100)

        @test user.username == "alice"
        @test length(user.password_hash) == 32
        @test length(user.salt) == 16
        @test user.iterations == 100

        # Test successful authentication
        @test authenticate(user, "secret123") == true

        # Test failed authentication
        @test authenticate(user, "wrong_password") == false
        @test authenticate(user, "secret124") == false
        @test authenticate(user, "") == false
    end

    @testset "User with Metadata" begin
        metadata = Dict("role" => "admin", "id" => 42)
        user = User("bob", "pass456"; iterations=100, metadata=metadata)

        @test user.metadata["role"] == "admin"
        @test user.metadata["id"] == 42
    end

    @testset "SingleUser Password Store" begin
        store = SingleUser("alice", "secret123"; iterations=100)

        # Test get_user
        user = get_user(store, "alice")
        @test !isnothing(user)
        @test user.username == "alice"

        # Test get_user with wrong username
        user_wrong = get_user(store, "bob")
        @test isnothing(user_wrong)

        # Test authenticate via store
        @test authenticate(store, "alice", "secret123") == true
        @test authenticate(store, "alice", "wrong") == false
        @test authenticate(store, "bob", "secret123") == false
    end

    @testset "HTTP Basic Auth Parsing" begin
        # Create a test password store
        store = SingleUser("testuser", "testpass"; iterations=100)

        # Test with valid credentials
        valid_auth = "Basic " * base64encode("testuser:testpass")
        request_valid = HTTP.Request("GET", "/", ["Authorization" => valid_auth])
        @test check_auth(request_valid, store) == true

        # Test with invalid password
        invalid_auth = "Basic " * base64encode("testuser:wrongpass")
        request_invalid = HTTP.Request("GET", "/", ["Authorization" => invalid_auth])
        @test check_auth(request_invalid, store) == false

        # Test with invalid username
        invalid_user = "Basic " * base64encode("wronguser:testpass")
        request_wronguser = HTTP.Request("GET", "/", ["Authorization" => invalid_user])
        @test check_auth(request_wronguser, store) == false

        # Test with no authorization header
        request_no_auth = HTTP.Request("GET", "/", [])
        @test check_auth(request_no_auth, store) == false

        # Test with malformed authorization header
        request_malformed = HTTP.Request("GET", "/", ["Authorization" => "Bearer token123"])
        @test check_auth(request_malformed, store) == false
    end

    @testset "Password with Special Characters" begin
        # Test passwords with special characters
        passwords = [
            "pass:word",
            "p@ssw0rd!",
            "пароль",  # Cyrillic
            "密码",    # Chinese
            "pass word",  # Space
            "p\$\$w",
        ]

        for pass in passwords
            user = User("user", pass; iterations=100)
            @test authenticate(user, pass) == true
            @test authenticate(user, pass * "x") == false
        end
    end

    @testset "ProtectedRoute Construction" begin
        app = App() do
            return DOM.h1("Test App")
        end

        # Test with explicit store constructor
        store1 = SingleUser("admin", "secret"; iterations=100)
        protected1 = ProtectedRoute(app, store1)
        @test protected1.password_store === store1
        @test protected1.realm == "Protected Area"
        @test protected1.max_attempts == 5
        @test protected1.lockout_window == 60.0

        # Test with custom parameters
        store2 = SingleUser("user", "pass"; iterations=100)
        protected2 = ProtectedRoute(app, store2;
                                   realm="Admin Area",
                                   max_attempts=3,
                                   lockout_window=120.0)
        @test protected2.password_store === store2
        @test protected2.realm == "Admin Area"
        @test protected2.max_attempts == 3
        @test protected2.lockout_window == 120.0
    end

    @testset "Empty and Edge Cases" begin
        # Empty password
        user_empty = User("user", ""; iterations=100)
        @test authenticate(user_empty, "") == true
        @test authenticate(user_empty, "x") == false

        # Very long password
        long_pass = "a" ^ 1000
        user_long = User("user", long_pass; iterations=100)
        @test authenticate(user_long, long_pass) == true
        @test authenticate(user_long, long_pass * "x") == false

        # Username with special characters
        user_special = User("user@example.com", "pass"; iterations=100)
        @test user_special.username == "user@example.com"
        @test authenticate(user_special, "pass") == true
    end

    @testset "HTTP Server Integration" begin
        # Start server once for all HTTP tests
        port = rand(8000:9000)
        server = Bonito.Server("127.0.0.1", port)
        base_url = online_url(server, "/")

        try
            @testset "Basic Authentication Flow" begin
                # Create a simple app
                app = App() do
                    return DOM.div(
                        DOM.h1("Protected Content"),
                        DOM.p("You are authenticated!")
                    )
                end

                store = SingleUser("testuser", "testpass"; iterations=100)
                protected_app = ProtectedRoute(app, store)
                route!(server, "/" => protected_app)

                # Test 1: Request without authentication should get 401
                response_no_auth = HTTP.get(base_url; status_exception=false)
                @test response_no_auth.status == 401
                @test HTTP.header(response_no_auth, "WWW-Authenticate") == "Basic realm=\"Protected Area\""
                @test occursin("401", String(response_no_auth.body))

                # Test 2: Request with wrong credentials should get 401
                wrong_auth = "Basic " * base64encode("testuser:wrongpass")
                response_wrong = HTTP.get(base_url;
                                         headers=["Authorization" => wrong_auth],
                                         status_exception=false)
                @test response_wrong.status == 401

                # Test 3: Request with correct credentials should succeed
                valid_auth = "Basic " * base64encode("testuser:testpass")
                response_valid = HTTP.get(base_url;
                                         headers=["Authorization" => valid_auth],
                                         status_exception=false)
                @test response_valid.status == 200
                body_text = String(response_valid.body)
                @test occursin("Protected Content", body_text)
            end

            @testset "Rate Limiting" begin
                app = App() do
                    return DOM.h1("Content")
                end

                store = SingleUser("ratelimit", "test"; iterations=100)
                protected_app = ProtectedRoute(app, store; max_attempts=5)
                route!(server, "/" => protected_app)  # Overwrites previous route

                # Make 6 failed attempts
                for i in 1:6
                    HTTP.get(base_url;
                            headers=["Authorization" => "Basic " * base64encode("user:wrong")],
                            status_exception=false)
                end

                # Next request should be rate limited (429)
                response_limited = HTTP.get(base_url;
                                           headers=["Authorization" => "Basic " * base64encode("user:wrong")],
                                           status_exception=false)
                @test response_limited.status == 429
                @test HTTP.header(response_limited, "Retry-After") == "60"
                @test occursin("429", String(response_limited.body))
            end

            @testset "Custom Error Pages" begin
                # Create custom error pages
                custom_401 = App() do
                    return DOM.div(
                        DOM.h1("Custom 401 Page"),
                        DOM.p("Please login to continue")
                    )
                end

                custom_429 = App() do
                    return DOM.div(
                        DOM.h1("Custom 429 Page"),
                        DOM.p("You have been rate limited")
                    )
                end

                app = App() do
                    return DOM.h1("Main App Content")
                end

                store = SingleUser("user", "pass"; iterations=100)
                protected = ProtectedRoute(app, store;
                                           auth_required_handler=custom_401,
                                           rate_limited_handler=custom_429,
                                           max_attempts=2)
                route!(server, "/" => protected)  # Overwrites previous route

                # Test custom 401 page
                response_401 = HTTP.get(base_url; status_exception=false)
                @test response_401.status == 401
                body_401 = String(response_401.body)
                @test occursin("Custom 401 Page", body_401)
                @test occursin("Please login to continue", body_401)

                # Test custom 429 page after exceeding rate limit
                for i in 1:3
                    HTTP.get(base_url;
                            headers=["Authorization" => "Basic " * base64encode("user:wrongpass")],
                            status_exception=false)
                end
                response_429 = HTTP.get(base_url;
                                       headers=["Authorization" => "Basic " * base64encode("user:wrongpass")],
                                       status_exception=false)
                @test response_429.status == 429
                body_429 = String(response_429.body)
                @test occursin("Custom 429 Page", body_429)
                @test occursin("You have been rate limited", body_429)

                # Test that correct credentials still work
                valid_auth = "Basic " * base64encode("user:pass")
                response_success = HTTP.get(base_url;
                                           headers=["Authorization" => valid_auth],
                                           status_exception=false)
                @test response_success.status == 200
                body_success = String(response_success.body)
                @test occursin("Main App Content", body_success)
            end

        finally
            # Stop server once after all tests
            close(server.server)
        end
    end

    @testset "Combined Handlers" begin
        port = rand(8000:9000)
        server = Bonito.Server("127.0.0.1", port)
        base_url = online_url(server, "/")

        # Create test directories with files
        test_dir = mktempdir()
        public_dir = joinpath(test_dir, "public")
        private_dir = joinpath(test_dir, "private")
        mkdir(public_dir)
        mkdir(private_dir)

        # Create test files
        write(joinpath(public_dir, "index.html"), "<h1>Public Content</h1>")
        write(joinpath(public_dir, "about.html"), "<h1>About Us</h1>")
        write(joinpath(private_dir, "index.html"), "<h1>Private Content</h1>")
        write(joinpath(private_dir, "secret.html"), "<h1>Secret Data</h1>")

        try
            @testset "LoggingHandler" begin
                log_file = tempname()
                admin_app = App(DOM.h1("Super Secret Admin"))
                logged_app = LoggingHandler(admin_app, log_file)
                single_user = SingleUser("admin", "s3cr3t"; iterations=100)
                protected_app = ProtectedRoute(logged_app, single_user)

                route!(server, "/admin" => protected_app)

                # Test authenticated access
                valid_auth = "Basic " * base64encode("admin:s3cr3t")
                response = HTTP.get(base_url * "admin";
                                   headers=["Authorization" => valid_auth],
                                   status_exception=false)
                @test response.status == 200
                @test occursin("Super Secret Admin", String(response.body))

                # Verify logging happened
                @test isfile(log_file)
                log_content = read(log_file, String)
                @test occursin("GET /admin", log_content)

                rm(log_file)
            end

            @testset "FolderServer - Public" begin
                public_files = FolderServer(public_dir)
                route!(server, r"/public/.*" => public_files)

                # Test accessing public index
                response = HTTP.get(base_url * "public/"; status_exception=false)
                @test response.status == 200
                @test occursin("Public Content", String(response.body))

                # Test accessing public file
                response = HTTP.get(base_url * "public/about.html"; status_exception=false)
                @test response.status == 200
                @test occursin("About Us", String(response.body))

                # Test 404 for non-existent file
                response = HTTP.get(base_url * "public/nonexistent.html"; status_exception=false)
                @test response.status == 404
            end

            @testset "FolderServer - Protected" begin
                single_user = SingleUser("admin", "s3cr3t"; iterations=100)
                protected_files = ProtectedRoute(FolderServer(private_dir), single_user)
                route!(server, r"/private/.*" => protected_files)

                # Test accessing without auth
                response = HTTP.get(base_url * "private/"; status_exception=false)
                @test response.status == 401

                # Test accessing with wrong auth
                wrong_auth = "Basic " * base64encode("admin:wrong")
                response = HTTP.get(base_url * "private/";
                                   headers=["Authorization" => wrong_auth],
                                   status_exception=false)
                @test response.status == 401

                # Test accessing with correct auth
                valid_auth = "Basic " * base64encode("admin:s3cr3t")
                response = HTTP.get(base_url * "private/";
                                   headers=["Authorization" => valid_auth],
                                   status_exception=false)
                @test response.status == 200
                @test occursin("Private Content", String(response.body))

                # Test accessing specific file with auth
                response = HTTP.get(base_url * "private/secret.html";
                                   headers=["Authorization" => valid_auth],
                                   status_exception=false)
                @test response.status == 200
                @test occursin("Secret Data", String(response.body))
            end

        finally
            close(server.server)
            rm(test_dir; recursive=true)
        end
    end
end

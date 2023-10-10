# Deployment

```@example 1
using JSServe
example_app = App(DOM.div("hello world"), title="hello world")
```

## Server

```julia
# Depending on your servers setup, you may need to listen on another port or URL
# But 0.0.0.0:80 is pretty standard for most server setups
port = 80
url = "0.0.0.0"
server = JSServe.Server(example_app, url, port)
```

Now, you should see the webpage at `http://0.0.0.0:80`.

### Proxy + Julia Hub

If the server is behind a proxy, you can set the proxy like this:

```@example 1
server = JSServe.Server(example_app, "0.0.0.0", 8080; proxy_url="https://my-domain.de/my-app");
# or set it later
# this can be handy for interactive use cases where one isn't sure which port is open, and let JSServe find a free port (which will then be different from the one created with, but is stored in `server.port`)
server.proxy_url = ".../$(server.port)"
```

JSServe tries to do this for known environments like JuliaHub via `get_server()`.
This will find the most common proxy setup and return a started server:

```@example 1
server = JSServe.get_server()
# add a route to the server for root to point to our example app
route!(server, "/" => example_app)
```
The url which this site is now served on can be found via:

```@example 1
# Here in documenter, this will just return a localhost url
url_to_visit = online_url(server, "/")
```

Like this, one can also add multiple pages:
```@example 1
page_404 = App() do session, request
    return DOM.div("no page for $(request.target)")
end
# You can use string (paths), or a regex
route!(server, r".*" => page_404)
route!(server, "/my/nested/page" => App(DOM.div("nested")))
url_to_visit = online_url(server, "/my/nested/page")
```

### nginx
If you need to re-route JSServe (e.g. to host in parallel to PlutoSliderServer, you want a reverse-proxy like `nginx`. We did some testing with nginx and the following configuration worked for us:
```nginx
server {
    listen 8080;
    location /jsserve/ {
        proxy_pass http://localhost:8081/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
}
```
and the JSServer with:
```julia
    server = Server("127.0.0.1", 8081;proxy_url="https://www.abc.org/jsserve/")
    route!(server,"/"=>app) # with app an JSServe app
    # close(server) # useful for debugging ;)
```
This would re-route `www.abc.org:8080/jsserve/` to your local JSServe-Server.

If you get errors in your browser console relating to "GET", "MIME-TYPE"

1. First make sure that the URL of the assets is "correct", that is, there is no `//` somewhere in the domain, and in principle the client tries to find the correct target (`Server(...,verbose=1)` might help to see if requests arrive).
2. if the app shows up fine, but you get these errors (typically with wss:// in the front, indicating some websocket issue), double check that all the slashes `/` in your configuration are set correct. That is all these 4 paths should have `/`'s at the end: `location /subfolder/`, `proxy_pass =.../`  `Server(...,proxy_url=".../")` and `route!(...,'/'=>app)`
3. If it still doesnt work, you might need to look into websocket forwarding - or you might have an intermediate reverse-proxy that blocks the websocket.

### Heroku

Deploying to Heroku with JSServe works pretty similar to this [blogpost](https://towardsdatascience.com/deploying-julia-projects-on-heroku-com-eb8da5248134).

```
mkdir my-app
cd my-app
julia --project=. -e 'using Pkg; Pkg.add("JSServe")' # and any other dependency
```

then create 2 files:

`app.jl`:
```julia
using JSServe
# The app you want to serve
#  Note: you can also add more pages with `route!(server, ...)` as explained aboce
my_app = App(DOM.div("hello world"))
port = parse(Int, ENV["PORT"])
# needs to match `heroku create - a example-app`,
# which we can ensure by using the env variable
# which is only available in review app, so one needs to fill this in manually for now
# https://devcenter.heroku.com/articles/github-integration-review-apps#injected-environment-variables
my_app_name = get(ENV, "HEROKU_APP_NAME", "example-app")
url = "https://$(my_app_name).herokuapp.com/"
wait(JSServe.Server(my_app, "0.0.0.0", port, proxy_url=url))
```
`Procfile`:
```
web: julia --project=. app.jl
```

and then to upload the app install the [heroku-cli](https://devcenter.heroku.com/articles/heroku-cli) and run as explained in the [heroku git deploy section](https://devcenter.heroku.com/articles/git):

```
$ cd my-app
$ git init
$ git add .
$ git commit -m "first commit"
$ heroku create -a example-app
$ heroku git:remote -a example-app
```
Which, after showing you the install logs, should print out the url to visit in the end.
You can see the full example here:

https://github.com/SimonDanisch/JSServe-heroku

## Terminal
If no HTML display is found in the Julia display stack, JSServe calls `JSServe.enable_browser_display()` in the `__init__` function.
This adds a display, that opens a browser window to display the app
The loading of the `BrowserDisplay` happen in any kind of environment without html display, so this should also work in any kind of terminal or when evaluating a script.

```julia
> using JSSever
> example_app # just let the display system display it in a browser window
```

## VScode

VScode with enabled `Plot Pane` will display any `JSServe.App` in the HTML plotpane:
![](vscode.png)

## Notebooks

Most common notebook systems should work out of the box.

### IJulia
![](ijulia.png)

### Jupyterlab
![](jupyterlab.png)

### Pluto
![](pluto.png)

## Electron

```julia
using Electron, JSServe
# Needs to be called after loading Electron
JSServe.use_electron_display()
# display(...) can be skipped in e.g. VSCode with disabled plotpane
display(example_app)
```
![](electron.png)

!!! note
    By default, `JSServe` will create the Electron window without showing the Developer
    Tools panel. You can control this behavior at
    window creation using the `devtools` keyword arg:
    ```
    display = JSServe.use_electron_display(devtools = true)
    ```
    Alternatively, you can toggle the Developer Tools at any later time using:
    ```
    Electron.toggle_devtools(display.window)
    ```

## Documenter

JSServe works in Documenter without additional setup.
But, one always needs to include a block like this before any other code block displaying JSServe Apps:

```julia
using JSServe
Page()
```
This is needed, since JSServe structures the dependencies and state per Page, which needs to be unique per documentation page.
One can use the JSServe documentation source to see an example.

## Static export


## Anything else

JSServe overloads the `display`/`show` stack for the mime `"text/html"` so any other Software which is able to display html in Julia should work with JSServe.
If a use case is not supported, please open an issue.
One can also always directly call:
```julia
html_source = sprint(io-> show(io, MIME"text/html"(), example_app))
```
Do get the html source code as a string (or just write it to the io).

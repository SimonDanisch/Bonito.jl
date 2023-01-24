# Deploying your app

```@example 1
using JSServe
example_app = App(DOM.div("hello world"), title="hello world")
```

## Server

```@example 1
# Depending on your servers setup, you may need to listen on another port or URL
# But 0.0.0.0:80 is pretty standard for most server setups
port = 80
url = "0.0.0.0"
server = JSServe.Server(example_app, url, port)
nothing
```

Now, you should see the webpage at `http://0.0.0.0:80`.

### Proxy + Julia Hub

If the server is behind a proxy, you can set the proxy like this:

```@example 1
server = JSServe.Server(example_app, url, 8080; proxy_url="https://my-domain.de/my-app");
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
route!(server, r"my/nested/page" => App(DOM.div("nested")))
url_to_visit = online_url(server, "/my/nested/page")
```


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

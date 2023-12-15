# Static Sites

There are several ways to generate static sites with Bonito.
The main one is:

```@docs
export_static
```

The simplest one, which also allows an interactive Revise based workflow is enabled by `interactive_server`:

```@docs
interactive_server
```

When exporting interactions defined within Julia not using Javascript, one can use, to cache all interactions:

```@docs
Bonito.record_states
```

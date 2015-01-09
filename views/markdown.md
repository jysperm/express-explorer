<% if (package) { %>
# <%= package.name %>
<% } else { %>
# API Document
<% } %>

## Endpoints
<% routers.forEach(function(router) { %>
### [<%= router.method %>] <%= router.path %>

```
<%= router.source %>
```

<% }); %>

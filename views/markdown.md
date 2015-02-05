<% if (package) { %>
# <%= package.name %>

* Version: <%= package.version %>

<% } else { %>
# API Document
<% } %>

# Global Middlewares

<%
stacks.forEach(function(layer) {
  if (layer.type == 'middleware' && layer.path == '/') { %>

* <%= layer.handle_name %>

<%  
  }
});

%>

# Endpoints
<%

var helpers = {
  headerN: headerN,
  escapeMarkdown: escapeMarkdown
};

function displayEndpoint(endpoint, level) {
  if (endpoint.type == 'route') { %>

<%= helpers.headerN(level) %> [<%= endpoint.method %>] <%= helpers.escapeMarkdown(endpoint.path) %>
<% if (endpoint.middlewares && endpoint.middlewares.length) { %>
Middlewares: `<%= endpoint.middlewares.join('`, `') %>`  
<% } %>

<%
  } else {
    if (level != 1) { %>

<%= helpers.headerN(level) %> [Router] <%= helpers.escapeMarkdown(endpoint.path) %>

<%
    }

    endpoint.forEach(function(endpoint) {
      displayEndpoint(endpoint, level + 1);
    });
  }
}

displayEndpoint(endpoints, 1);

%>

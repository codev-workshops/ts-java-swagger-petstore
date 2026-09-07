package io.swagger.petstore.bdd;

import io.swagger.oas.inflector.OpenAPIInflector;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.ServerConnector;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import org.glassfish.jersey.servlet.ServletContainer;

/**
 * Boots the Swagger Inflector application from src/main/resources/openapi.yaml and inflector.yaml
 * on an embedded Jetty server, mirroring the servlet mapping declared in web.xml.
 */
final class PetstoreServer {

    private static Server server;
    private static String baseUrl;

    private PetstoreServer() {
    }

    static synchronized void start() throws Exception {
        if (server != null) {
            return;
        }
        server = new Server();
        final ServerConnector connector = new ServerConnector(server);
        connector.setPort(0);
        server.addConnector(connector);

        final ServletContextHandler context = new ServletContextHandler(ServletContextHandler.NO_SESSIONS);
        context.setContextPath("/");
        final ServletHolder holder = new ServletHolder("swagger-inflector", ServletContainer.class);
        holder.setInitParameter("javax.ws.rs.Application", OpenAPIInflector.class.getName());
        holder.setInitParameter("jersey.config.server.provider.packages",
                "com.fasterxml.jackson.jaxrs.yaml.JacksonYAMLProvider");
        holder.setInitOrder(1);
        context.addServlet(holder, "/api/*");
        server.setHandler(context);

        server.start();
        baseUrl = "http://localhost:" + connector.getLocalPort() + "/api/v3";
    }

    static synchronized void stop() throws Exception {
        if (server != null) {
            server.stop();
            server = null;
        }
    }

    static String baseUrl() {
        return baseUrl;
    }
}

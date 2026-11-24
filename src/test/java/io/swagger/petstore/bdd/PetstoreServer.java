package io.swagger.petstore.bdd;

import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.ServerConnector;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import org.glassfish.jersey.servlet.ServletContainer;

/** Starts the Petstore webapp (same servlet setup as WEB-INF/web.xml) once per JVM on a free port. */
final class PetstoreServer {

    private static String baseUrl;

    private PetstoreServer() {
    }

    static synchronized String baseUrl() {
        if (baseUrl != null) {
            return baseUrl;
        }
        final String external = System.getProperty("petstore.baseUrl");
        if (external != null && !external.isEmpty()) {
            baseUrl = external.replaceAll("/+$", "");
            return baseUrl;
        }
        try {
            final Server server = new Server(0);
            final ServletContextHandler context = new ServletContextHandler(ServletContextHandler.NO_SESSIONS);
            context.setContextPath("/");
            final ServletHolder holder = context.addServlet(ServletContainer.class, "/api/*");
            holder.setInitParameter("javax.ws.rs.Application", "io.swagger.oas.inflector.OpenAPIInflector");
            holder.setInitParameter("jersey.config.server.provider.packages",
                    "com.fasterxml.jackson.jaxrs.yaml.JacksonYAMLProvider");
            holder.setInitOrder(1);
            server.setHandler(context);
            server.start();
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                try {
                    server.stop();
                } catch (Exception ignored) {
                    // JVM is exiting
                }
            }));
            baseUrl = "http://localhost:" + ((ServerConnector) server.getConnectors()[0]).getLocalPort();
            return baseUrl;
        } catch (Exception e) {
            throw new IllegalStateException("Could not start embedded Petstore server", e);
        }
    }
}

package mc.server;

/**
 * Created by malharchaudhari on 4/20/17.
 */

import io.undertow.Handlers;
import io.undertow.Undertow;
import io.undertow.server.HttpHandler;
import io.undertow.server.handlers.PathHandler;
import io.undertow.servlet.api.DeploymentInfo;
import io.undertow.servlet.api.DeploymentManager;
import mc.server.servlets.ServletMaster;
import io.undertow.UndertowOptions;
import javax.servlet.ServletException;

import static io.undertow.servlet.Servlets.*;


public class Server {
    private static final String PATH = "/";

    public static void main(String[] args) {

        try {
            DeploymentInfo servletBuilder = deployment()
                    .setClassLoader(Server.class.getClassLoader())
                    .setContextPath(PATH)
                    .setDeploymentName("handler.war")
                    .addServlets(servlet("mc.server.servlets.ServletMaster", ServletMaster.class).addMapping("/master"));

            DeploymentManager manager = defaultContainer().addDeployment(servletBuilder);
            manager.deploy();

            HttpHandler servletHandler = manager.start();

            PathHandler path = Handlers.path(Handlers.redirect(PATH))
                    .addPrefixPath(PATH, servletHandler);

            Undertow server = Undertow.builder().setServerOption(UndertowOptions.MAX_HEADER_SIZE, 10485760)
                    .addHttpListener(80, "0.0.0.0")
                    .setHandler(path)
                    .build();
            server.start();
        } catch (ServletException ignored) {
            ignored.printStackTrace();
        }
    }
}
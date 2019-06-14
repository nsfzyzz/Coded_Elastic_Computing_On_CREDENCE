package mc.server.servlets;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.PrintWriter;
import java.util.Map;

/**
 * Defines a servlet at the node. <P> Defines the mapping between query object and the corresponding methods when the
 * request is routed to this servlet. Currently post requests are routed as get requests.
 *
 * @author Malhar Chaudhari
 * @version 1.0
 */

public class ServletWorker extends HttpServlet {

    /**
     * Defines the mapping between parameter map and the methods to be called in the corresponding App file with the
     * keys in the parameter map as the argument inputs to the methods
     *
     * @param request  The HttpServletRequest being sent to this servlet
     * @param response The response to the received GET Request. HttpServletResponse object response reads the output
     *                 stream written to by the methods called by the request
     */
    @Override
    protected void doGet(final HttpServletRequest request, final HttpServletResponse response) {

        try {
            request.setCharacterEncoding("UTF-8");
            response.setCharacterEncoding("UTF-8");

            PrintWriter printWriter = new PrintWriter(response.getOutputStream());

            String prodVect = "";

            Map<String, String[]> paramMap = request.getParameterMap();
            for (String param : paramMap.keySet()) {
                if (param.equals("vectIn")) {
                    AppWorker appWorker = new AppWorker();
                    prodVect = appWorker.vectMatMult(paramMap.get(param)[0]);
                }
            }

            printWriter.print(prodVect);

            printWriter.flush();
            printWriter.close();
        } catch (Exception ignored) {
            ignored.printStackTrace();
        }
    }

    /**
     * Routes the received request to doGet method
     *
     * @param request  Routes the request to the doGet methods
     * @param response Routes the response via doGet methods
     */
    @Override
    protected void doPost(final HttpServletRequest request, final HttpServletResponse response) {
        doGet(request, response);
    }
}

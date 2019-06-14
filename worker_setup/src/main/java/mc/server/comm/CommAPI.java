package mc.server.comm;

import com.mashape.unirest.http.Unirest;
import com.mashape.unirest.http.exceptions.UnirestException;
import org.apache.commons.io.IOUtils;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;

/**
 * Communication API Abstraction Library Class. <P> All communication related methods are part of this static class and
 * are implemented originally by com.mashape.unirest.http.Unirest. Creating an object of this class is not
 * allowed and should be used only as a static class methods. <P> Apart from communication API, it also contains methods
 * to support communication like CommAPI#stringURLEncode, CommAPI#stringURLDecode and CommAPI#getEC2DNSList
 *
 * @author Malhar Chaudhari
 * @version 1.0
 */

public final class CommAPI {
    /*
     * To avoid instantiating an object of this class */
    private CommAPI() {
    }

    /**
     * Sends GET request to the node being defined by the input parameters
     *
     * @param protocol       Application level protocol being used to send the request
     * @param dns            DNS of the node to which request is being sent
     * @param mapping        Mapping to the servlet on the node server to which request is being sent
     * @param queryStringMap Query key:value map for the servlet on the node to which request is being sent
     * @return Returns body of the response to the request, if no exception encountered
     * @throws IOException if connection cannot be established
     */
    public static String sendGetRequest(String protocol, String dns, String mapping, HashMap<String, Object> queryStringMap) throws IOException {
        String response;
        try {
            response = Unirest.get(protocol + "://" + dns + mapping).queryString(queryStringMap).asString().getBody();
            return response;
        } catch (UnirestException e) {
            e.printStackTrace();
            return null;
        }

    }

    /**
     * URL encodes a string before sending it over the network to avoid transmission errors and failures
     *
     * @param input Input string to be encoded
     * @return Returns URL encoded string
     * @throws UnsupportedEncodingException if string cannot be encoded in UTF-8 format
     */
    public static String stringURLEncode(String input) throws UnsupportedEncodingException {
        return URLEncoder.encode(input, "UTF-8");
    }

    /**
     * Decodes a URL encoded string received by this node
     *
     * @param input URL encoded string
     * @return Returns the original string before being URL encoded
     * @throws UnsupportedEncodingException if string cannot be decoded in UTF-8 format
     */
    public static String stringURLDecode(String input) throws UnsupportedEncodingException {
        return URLDecoder.decode(input, "UTF-8");
    }

    /**
     * Reads the EC2 DNS List populated by the deployment script
     *
     * @param type Possible inputs are <code>master</code> or <code>worker</code> for reading the master or the worker
     *             node DNSs respectively
     * @param sep  The separator between the DNSs in the DNS List file
     * @return Returns an ArrayList of string containing the DNS, if no IOException is thrown
     */
    public static List<String> getEC2DNSList(String type, String sep) {
        ClassLoader classLoader = CommAPI.class.getClassLoader();
        String result = "";
        try {
            result = IOUtils.toString(classLoader.getResourceAsStream("ec2_" + type + "_dns_list"), "UTF-8").trim();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return Arrays.asList(result.split(sep));
    }

    /**
     * Sets the connection and socket timeout for the GET requests
     *
     * @param connTimeout   The timeout until a connection with the server is established (in milliseconds). Default is
     *                      10000. Set to zero to disable the timeout.
     * @param socketTimeout The timeout to receive data (in milliseconds). Default is 60000. Set to zero to disable the
     *                      timeout.
     */
    public static void setReqTimeout(long connTimeout, long socketTimeout) {
        Unirest.setTimeouts(connTimeout, socketTimeout);
    }

    /**
     * Set default header for the GET request
     *
     * @param Header The header input as a string
     * @param Value  The value for the corresponding header as a string
     */
    public static void setDefaultHeaders(String Header, String Value) {
        Unirest.setDefaultHeader(Header, Value);
    }

    /**
     * Set the concurrency levels for the GET request
     *
     * @param maxTotal    Defines the overall connection limit for a connection pool. Default is 200.
     * @param maxPerRoute Defines a connection limit per one HTTP route (this can be considered a per target host
     *                    limit). Default is 20.
     */
    public static void setReqConcurrency(int maxTotal, int maxPerRoute) {
        Unirest.setConcurrency(maxTotal, maxPerRoute);
    }

    /**
     * Close the asynchronous client and its event loop. Use this method to close all the threads and allow an
     * application to exit.
     *
     * @throws IOException if Unirest fails to shutdown all threads
     */
    private static void unirestShutdown() throws IOException {
        Unirest.shutdown();
    }
}

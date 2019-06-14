package mc.server.servlets;

import mc.server.comm.CommAPI;
import mc.server.types.TypeMatrixDouble;
import mc.server.types.TypeVectorDouble;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.List;

/**
 * Defines the tasks done at the worker nodes
 * This is the Main Server to be run on worker nodes, with the custom functions
 *
 * @author Yaoqing Yang
 */

class AppWorker {

    final private static Logger logger = LogManager.getLogger(AppWorker.class);
    private List<String> dns_arr_master = CommAPI.getEC2DNSList("master", ",");
    
    final private static int RecThreshold = 10;
    final private static int OverallSize = 105000;
    //final private static int OverallSize = 180;

    final private static int NumWorkers_initial = 20;
    final private static int ReceiveSize = 10000;
    //final private static int ReceiveSize = 5;

    final private static int SamplePerWorker = OverallSize/NumWorkers_initial;
    final private static int CodedSamplePerWorker = SamplePerWorker*(NumWorkers_initial/RecThreshold);

    private static int NumWorkers = NumWorkers_initial;
    private static int SendSize = CodedSamplePerWorker/NumWorkers*RecThreshold;
    private static int elastic_size = CodedSamplePerWorker/NumWorkers;

    private static boolean if_init = true; // Indicate this is the first iteration
    private static int workerNum;
    private static TypeMatrixDouble GeneratorMatrix;

    public static TypeMatrixDouble mat = new TypeMatrixDouble(1,1,0,1);

    String vectMatMult(String vectInStr) {
        String vectResp = "";
        try {
            
            if (if_init) {

                if_init = false;
                // Initial stage to generate data
                TypeVectorDouble vectConcat = new TypeVectorDouble(1+NumWorkers_initial*RecThreshold);
                vectConcat.deserialize(CommAPI.stringURLDecode(vectInStr), ",");
                GeneratorMatrix = new TypeMatrixDouble(NumWorkers_initial, RecThreshold, vectConcat);

                workerNum = (int) vectConcat.GetVect()[NumWorkers_initial*RecThreshold];
                logger.info("This worker has worker number" + workerNum);

                // Generate the partial data
                mat = new TypeMatrixDouble(CodedSamplePerWorker, ReceiveSize, mat.generate_data(workerNum, GeneratorMatrix.GetMat(), CodedSamplePerWorker, ReceiveSize));

            }
            else {

                //TypeMatrixDouble mat = new TypeMatrixDouble(matSize, matSize, 0, 100);
                TypeVectorDouble vectIn = new TypeVectorDouble( ReceiveSize );

                long matProdTimeStart = System.nanoTime();
                vectIn.deserializeWithControlInfo(CommAPI.stringURLDecode(vectInStr), ",");

                if (vectIn.GetControlInfo() != NumWorkers) {
                    // The number of workers has changed
                    NumWorkers = vectIn.GetControlInfo();
                    UpdateSettingsWhenNumMachinesChange();

                }

                //TypeVectorDouble vectFin = new TypeVectorDouble(SendSize, mat.matVectMult(vectIn));
                int startInd = ((NumWorkers - RecThreshold + workerNum) % NumWorkers)*elastic_size;
                //logger.info("The start ind in this worker is " + startInd);

                TypeVectorDouble vectFin = new TypeVectorDouble(SendSize, mat.matVectMult_selected(vectIn, startInd, SendSize));
                vectResp =  CommAPI.stringURLEncode(vectFin.serialize(","));
                logger.info("Time Taken to Complete Matrix Vector Product is " + (System.nanoTime()-matProdTimeStart));

                //vectFin.writeVectToFile("/home/ubuntu/local_result.txt", "\n");
            }
        }
        catch (Exception e){
            logger.error(e.toString());
            e.printStackTrace();
        }
        return vectResp;
    }

    public void UpdateSettingsWhenNumMachinesChange() {

        // Randomly generate the number of machines
        SendSize = CodedSamplePerWorker/NumWorkers*RecThreshold;
        elastic_size = CodedSamplePerWorker/NumWorkers;

    }
}

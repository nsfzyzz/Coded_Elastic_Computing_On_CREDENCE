package mc.server.servlets;

import mc.server.comm.CommAPI;
import mc.server.types.TypeVectorDouble;
import mc.server.types.TypeMatrixDouble;
import mc.server.types.TypeVectorInt;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Random;
import org.apache.commons.lang3.ArrayUtils;

import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Defines the tasks done at the master nodes
 * This is the Main Server to be run on master node, with the custom functions
 *
 * @author Yaoqing Yang
 */

public class AppMaster {
    final private static int RecThreshold = 10;
    final private static int OverallSize = 105000;
    final private static int NumWorkers_initial = 20;
    final private static int SendSize = 10000;

    final private static int SamplePerWorker = OverallSize/NumWorkers_initial;
    final private static int CodedSamplePerWorker = SamplePerWorker*(NumWorkers_initial/RecThreshold);

    private static int[] NumWorkersSet = {10, 12, 15, 18, 20};
    private static int NumWorkers = NumWorkers_initial; // This number can change over time

    private static int ReceiveSize = CodedSamplePerWorker/NumWorkers*RecThreshold;
    private static int elastic_size = CodedSamplePerWorker/NumWorkers;

    final private static Logger logger = LogManager.getLogger(AppMaster.class);
    private List<String> dns_arr_workers = CommAPI.getEC2DNSList("worker", ",");
    private static AtomicReference<String> shared = new AtomicReference<>();
    volatile TypeMatrixDouble xt_receive = new TypeMatrixDouble(NumWorkers,ReceiveSize,0,0);
    private static TypeMatrixDouble Decoding_matrix = new TypeMatrixDouble(NumWorkers_initial,RecThreshold,-1,1);
    private TypeMatrixDouble[] Decoding_matrix_collections;
    private Random rand = new Random();
    private boolean ChangeNumMachinesCall = false; // Indicate a change on the number of machines

    public void initTask() {

        try {

            logger.info("------------------- Start the master task -------------------");

            Decoding_matrix_collections = select_encoding_matrix(Decoding_matrix);
            TypeMatrixDouble[] Received_rearranged = new TypeMatrixDouble[NumWorkers];
            long iter_num_all = 1000;
            long iter_num_not_count = 100;

            // The time_ave is for logging the average time for different configurations
            long[] time_ave = new long[NumWorkersSet.length];
            java.util.Arrays.fill(time_ave, 0);
            // The time_length is for logging the number of queries from different configurations
            long[] time_length = new long[NumWorkersSet.length];
            java.util.Arrays.fill(time_length, 0);
            // The time_log is for logging the time for each iteration
            long[] time_log = new long[(int) (iter_num_all-iter_num_not_count)];
            java.util.Arrays.fill(time_log, 0);

            for (long iter_num = 0; iter_num < iter_num_all + 1; iter_num++) {

                logger.info("------------------- This is the " + iter_num + "-th iteration -------------------");

                if (iter_num > 0 && Math.random() < 0.02) {

                    int NumWorkers_old = NumWorkers;
                    while (NumWorkers_old == NumWorkers) {
                        NumWorkers = NumWorkersSet[rand.nextInt(NumWorkersSet.length)];
                    }

                    logger.info("The number of machines changes to " + NumWorkers + "!!");
                    // Change the settings on the master
                    ChangeNumMachinesCall = true;
                    UpdateSettingsWhenNumMachinesChange();

                }

                // Generate a random input vector
                TypeVectorDouble vect = new TypeVectorDouble(SendSize + 1, 0, 100);
                vect.SetValue((double) NumWorkers, SendSize);

                long SerializeTimeStart = System.nanoTime();

                // Serialize
                // Set the input vector to the atomic reference for different threads to access
                shared.set(CommAPI.stringURLEncode(vect.serialize(",")));
                //logger.info("Time taken to complete vector serialization is " + (System.nanoTime() - SerializeTimeStart) / 1000000);


                // Start the threads

                long ThreadTimeStart = System.nanoTime();
                ExecutorService executor = Executors.newFixedThreadPool(NumWorkers);
                int count = 0;

                for (String dns : dns_arr_workers) {

                    // Only send data to the remaining workers
                    count++;
                    if (count > NumWorkers) {
                        break;
                    }
                    int ind = dns_arr_workers.indexOf(dns);
                    Runnable worker = new MyRunnable(dns, ind, ReceiveSize, ThreadTimeStart, iter_num);
                    executor.execute(worker);

                }
                // Shut down threads
                executor.shutdown();
                while (!executor.isTerminated()) {

                }
                logger.info("Time taken to complete all communication round is " + (System.nanoTime() - ThreadTimeStart) / 1000000);

                if (iter_num == 0 || ChangeNumMachinesCall) {
                    // the first iteration is only for sending the worker id
                    // when NumWorkers changes, broadcast the NumWorkers
                    // no need to decode in these two situations
                    ChangeNumMachinesCall = false;
                    continue;

                } else {

                    // Decoding
                    long DecodingTimeStart = System.nanoTime();

                    // rearrange the received vectors

                    for (int group_ind = 0; group_ind < NumWorkers; group_ind++) {

                        Received_rearranged[group_ind] = new TypeMatrixDouble(RecThreshold, elastic_size);

                        int start_block_in_node = (1 + group_ind) % NumWorkers;
                        for (int node_in_this_group = 0; node_in_this_group < RecThreshold; node_in_this_group++) {
                            int node_id = (start_block_in_node + node_in_this_group) % NumWorkers;
                            int row_id = (NumWorkers - 1 - node_in_this_group) % RecThreshold;
                            Received_rearranged[group_ind].set_row(node_in_this_group, xt_receive.sub_row(node_id, row_id * elastic_size, elastic_size));
                        }
                        TypeMatrixDouble prodMatrix = Decoding_matrix_collections[group_ind].matMatMultGiveMat(Received_rearranged[group_ind]);

                        if (iter_num == 1 && group_ind == 0) {
                            try {
                                prodMatrix.writeMatToFile("/home/ubuntu/result.txt", " ", "\n");
                                double vectSum = vect.vecSum();

                                TypeVectorDouble vectSum0 = new TypeVectorDouble(1, new double[]{vectSum});
                                vectSum0.writeVectToFile("/home/ubuntu/vector_sum.txt", " ");

                            } catch (IOException e) {
                                e.printStackTrace();
                            }
                        }
                    }
                    logger.info("Time taken to complete decoding is " + (System.nanoTime() - DecodingTimeStart) / 1000000);

                    if (iter_num > iter_num_not_count) {
                        // Log the timing information
                        long timeSpent = (System.nanoTime() - ThreadTimeStart) / 1000000;
                        time_log[(int) (iter_num - 1 - iter_num_not_count)] = timeSpent;
                        //int configureInd = Arrays.asList(NumWorkersSet).indexOf(NumWorkers);
                        int configureInd = ArrayUtils.indexOf(NumWorkersSet, NumWorkers);
                        if (configureInd == -1) {
                            throw new ArithmeticException("Number of workers is not properly updated!!");
                        }
                        time_length[configureInd] += 1;
                        time_ave[configureInd] += timeSpent;
                    }
                }
            }

            for (int i = 0; i < time_ave.length; i++) {
                logger.info("Average time per iteration when NumWorkers = " + NumWorkersSet[i] +
                        " is " + time_ave[i] / time_length[i] + " and the number of iterations is " + time_length[i]);
            }

            logger.info("The following is the log of the per-iteration time:\n");
            String u = "";

            for (int i = 0; i < time_log.length; i++) {
                u += time_log[i]+", ";
            }
            logger.info(u + "\n");

            TypeVectorInt time_log_to_file = new TypeVectorInt((int) (iter_num_all - iter_num_not_count), time_log);
            time_log_to_file.writeVectToFile("/home/ubuntu/time_log.txt", " ");

        } catch (Exception e) {
            logger.error(e.toString());
            e.printStackTrace();
        }
    }

    public void UpdateSettingsWhenNumMachinesChange() {

        // Randomly generate the number of machines
        ReceiveSize = CodedSamplePerWorker/NumWorkers*RecThreshold;
        elastic_size = CodedSamplePerWorker/NumWorkers;
        xt_receive = new TypeMatrixDouble(NumWorkers,ReceiveSize,0,0);
        Decoding_matrix_collections = select_encoding_matrix(Decoding_matrix);

    }
    public TypeMatrixDouble[] select_encoding_matrix(TypeMatrixDouble Decoding_matrix) {

        TypeMatrixDouble[] Generator_matrix_collections = new TypeMatrixDouble[NumWorkers];
        TypeMatrixDouble[] Decoding_matrix_collections = new TypeMatrixDouble[NumWorkers];
        
        int start_ind;

        int ind;

        for (int i=0; i<NumWorkers; i++) {

            Generator_matrix_collections[i] = new TypeMatrixDouble(RecThreshold,RecThreshold,0,100);
            Decoding_matrix_collections[i] = new TypeMatrixDouble(RecThreshold,RecThreshold,0,100);
            
            start_ind = i+1;
            for (int j=0; j<RecThreshold; j++) {

                // The ind is calculated using the cyclic shift method
                ind = (start_ind + j)%NumWorkers;
                Generator_matrix_collections[i].set_row(j,Decoding_matrix,ind);

            }

            Decoding_matrix_collections[i] = Generator_matrix_collections[i].matInv();

        }

        return Decoding_matrix_collections;
    }

    public class MyRunnable implements Runnable {
        private final String dns;
        private final int ind;
        private final int length;
        private final long multithreading_time_start;
        private final long iter_num;

        MyRunnable(String dns, int ind, int length, long multithreading_time_start, long iter_num) {
            this.dns = dns;
            this.ind = ind;
            this.length = length;
            this.multithreading_time_start = multithreading_time_start;
            this.iter_num = iter_num;
        }

         @Override
        public void run() {
            try {

                if (this.iter_num==0) {

                    double[] vectInd = new double[1];
                    vectInd[0] = this.ind;

                    double[] vectG = Decoding_matrix.toVect();

                    TypeVectorDouble vectConcat = new TypeVectorDouble(1+NumWorkers_initial*RecThreshold);
                    vectConcat.Concate(vectG, vectInd);

                    String vect = CommAPI.stringURLEncode(vectConcat.serialize(","));
                    String vectResp = CommAPI.sendGetRequest("http", dns, "/worker", new HashMap<String, Object>() {{ put("vectIn", vect); }});
                    logger.info("Send the worker id to worker "+ind);

                }
                else {

                    String vect = shared.get();
                    String vectResp = CommAPI.sendGetRequest("http", dns, "/worker", new HashMap<String, Object>() {{ put("vectIn", vect); }});
                    TypeVectorDouble finVect = new TypeVectorDouble(length);
                    finVect.deserialize(CommAPI.stringURLDecode(vectResp), ",");

                    xt_receive.set_row(this.ind, finVect);

                }
            }

            catch (Exception e) {
                e.printStackTrace();
            }
       }
    }
}

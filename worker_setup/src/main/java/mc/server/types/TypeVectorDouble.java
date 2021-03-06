package mc.server.types;

import java.io.*;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Defines a TypeVectorDouble object. <P> Provides methods to read a Double vector, vector serialization and
 * deserialization methods, and finally standard multiplication methods.
 *
 * @author Yaoqing Yang
 * @author Malhar Chaudhari
 * @version 2.0
 */

public class TypeVectorDouble {

    double[] vect;
    private int rowTotal;
    private int ControlInfo = -1;

    public int GetControlInfo() {return this.ControlInfo; }

    public double[] GetVect(){
        return this.vect;
    }

    /**
     * Constructor for class TypeVectorDouble. Creates a TypeVectorDouble object with all values initialized to 0.0.
     *
     * @param row Number of elements in the vector
     */
    public TypeVectorDouble(int row) {
        this.rowTotal = row;
        this.vect = new double[row];
    }

    /**
     * Constructor for class TypeVectorDouble. Creates a TypeVectorDouble object with all values initialized using
     * vectIn[] input.
     *
     * @param row    Number of elements in the vector
     * @param vectIn A double[] array from which the vector is initialized
     */
    public TypeVectorDouble(int row, double[] vectIn) {
        this.rowTotal = row;
        this.vect = vectIn;
    }

    /**
     * Constructor for class TypeVectorDouble. Creates a TypeVectorDouble object with all values initialized to random
     * values between randStart and randEnd inputs.
     *
     * @param row       Number of elements in the vector
     * @param randStart Double random start value
     * @param randEnd   Double random end value
     */
    public TypeVectorDouble(int row, double randStart, double randEnd) {
        this.rowTotal = row;
        this.vect = new double[row];

        for (int i = 0; i < row; i++) {
            this.vect[i] = ThreadLocalRandom.current().nextDouble(randStart, randEnd + 1);
        }
    }

    /**
     * Constructor for class TypeVectorDouble. Creates a TypeVectorDouble object with values read from the specified
     * filepath.
     *
     * @param row      Number of elements in the vector
     * @param filepath Path to the file from which the vector is to be read
     * @param sep      The character separator used to separate elements in the file
     */
    public TypeVectorDouble(int row, String filepath, String sep) {
        this.rowTotal = row;
        this.vect = new double[row];

        try {
            BufferedReader brVect = new BufferedReader(new FileReader(filepath));
            String rowLine;

            rowLine = brVect.readLine();
            String rowLineArr[] = rowLine.trim().split(sep);

            for (int i = 0; i < row; i++) {
                this.vect[i] = Double.parseDouble(rowLineArr[i]);
            }

            brVect.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Method for vector vector dot product
     *
     * @param vectIn Object of type TypeVectorDouble to be multiplied with this
     *               vector
     * @return The double value element as a result of the dot product
     */
    public double vectDotProd(TypeVectorDouble vectIn) {
        double dotProd = 0;

        for (int i = 0; i < this.rowTotal; i++) {
            dotProd += this.vect[i] * vectIn.vect[i];
        }

        return dotProd;
    }

    /**
     * Method to deserialize string to an object of type TypeVectorDouble
     *
     * @param vectIn Serialized vector as a string
     * @param sep    Character separator used to separate vector elements
     */
    public void deserialize(String vectIn, String sep) {
        String[] vectInArr = vectIn.trim().split(sep);

        for (int i = 0; i < this.rowTotal; i++) {
            this.vect[i] = Double.parseDouble(vectInArr[i]);
        }
    }

    /**
     * Method to deserialize string to an object of type TypeVectorDouble
     * The last double is reserved for control information
     *
     * @param vectIn Serialized vector as a string
     * @param sep    Character separator used to separate vector elements
     */
    public void deserializeWithControlInfo(String vectIn, String sep) {
        String[] vectInArr = vectIn.trim().split(sep);

        for (int i = 0; i < this.rowTotal; i++) {
            this.vect[i] = Double.parseDouble(vectInArr[i]);
        }

        this.ControlInfo = (int)Double.parseDouble(vectInArr[this.rowTotal]);
    }

    /**
     * Method for serializing object TypeVectorDouble to string
     *
     * @param sep Character separator used to separate vector elements
     * @return Returns a string serialized using the given separators
     */
    public String serialize(String sep) {
        StringBuilder vectBuilder = new StringBuilder();

        for (int i = 0; i < this.rowTotal; i++) {
            vectBuilder.append(this.vect[i]).append(sep);
        }

        return vectBuilder.toString().trim();
    }


    /**
     * Method to write an object of type TypeVectorDouble to specified file
     *
     * @param fpath The full path to the file where the vector is to be written
     * @param sep   Character separator to be used to separate vector elements
     * @throws IOException if writing to file fails
     */
    public void writeVectToFile(String fpath, String sep) throws IOException {
        PrintWriter vectWriter = new PrintWriter(new FileWriter(fpath));
        for (int i = 0; i < rowTotal; i++) {
            vectWriter.print(vect[i] + sep);
        }
        vectWriter.close();
    }
}

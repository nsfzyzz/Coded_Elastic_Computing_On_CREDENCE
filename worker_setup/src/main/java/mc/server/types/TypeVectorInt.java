package mc.server.types;

import java.io.*;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Defines a TypeVectorInt object. <P> Provides methods to read a Integer vector, vector serialization and
 * deserialization methods, and finally standard multiplication methods.
 *
 * @author Malhar Chaudhari
 * @version 1.0
 */

public class TypeVectorInt {

    int[] vect;
    private int rowTotal;

    /**
     * Constructor for class TypeVectorInt. Creates a TypeVectorInt object with all values initialized to 0.
     *
     * @param row Number of elements in the vector
     */
    public TypeVectorInt(int row) {
        this.rowTotal = row;
        this.vect = new int[row];
    }

    public int[] GetVect(){
        return this.vect;
    }

    /**
     * Constructor for class TypeVectorInt. Creates a TypeVectorInt object with all values initialized using vectIn[]
     * input.
     *
     * @param row    Number of elements in the vector
     * @param vectIn A int[] array from which the vector is initialized
     */
    public TypeVectorInt(int row, int[] vectIn) {
        this.rowTotal = row;
        this.vect = vectIn;
    }

    /**
     * Constructor for class TypeVectorInt. Creates a TypeVectorInt object with all values initialized to random values
     * between randStart and randEnd inputs.
     *
     * @param row       Number of elements in the vector
     * @param randStart Integer random start value
     * @param randEnd   Integer random end value
     */
    public TypeVectorInt(int row, int randStart, int randEnd) {
        this.rowTotal = row;
        this.vect = new int[row];

        for (int i = 0; i < row; i++) {
            this.vect[i] = ThreadLocalRandom.current().nextInt(randStart, randEnd + 1);
        }
    }

    /**
     * Constructor for class TypeVectorInt. Creates a TypeVectorInt object with values read from the specified
     * filepath.
     *
     * @param row      Number of elements in the vector
     * @param filepath Path to the file from which the vector is to be read
     * @param sep      The character separator used to separate elements in the file
     */
    public TypeVectorInt(int row, String filepath, String sep) {
        this.rowTotal = row;
        this.vect = new int[row];

        try {
            BufferedReader brVect = new BufferedReader(new FileReader(filepath));
            String rowLine;

            rowLine = brVect.readLine();
            String rowLineArr[] = rowLine.trim().split(sep);

            for (int i = 0; i < row; i++) {
                this.vect[i] = Integer.parseInt(rowLineArr[i]);
            }

            brVect.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Method for matrix vector multiplication
     *
     * @param matIn Object of type TypeMatrixInt to be multiplied with this vector
     * @return Returns an object of type TypeVectorInt as the result of matrix
     * vector multiplication
     */
    public int[] vectMatMult(TypeMatrixInt matIn) {
        int rowSum = 0;
        int[] prodVector = new int[matIn.colTotal];

        for (int i = 0; i < matIn.colTotal; i++) {
            for (int j = 0; j < this.rowTotal; j++) {
                rowSum += this.vect[j] * matIn.mat[j][i];
            }
            prodVector[i] = rowSum;
            rowSum = 0;
        }

        return prodVector;
    }

    /**
     * Method for vector vector dot product
     *
     * @param vectIn Object of type TypeVectorInt to be multiplied with this
     *               vector
     * @return The int value element as a result of the dot product
     */
    public int vectDotProd(TypeVectorInt vectIn) {
        int dotProd = 0;

        for (int i = 0; i < this.rowTotal; i++) {
            dotProd += this.vect[i] * vectIn.vect[i];
        }

        return dotProd;
    }

    /**
     * Method to deserialize string to an object of type TypeVectorInt
     *
     * @param vectIn Serialized vector as a string
     * @param sep    Character separator used to separate vector elements
     */
    public void deserialize(String vectIn, String sep) {
        String[] vectInArr = vectIn.trim().split(sep);

        for (int i = 0; i < this.rowTotal; i++) {
            this.vect[i] = Integer.parseInt(vectInArr[i]);
        }
    }

    /**
     * Method for serializing object TypeVectorInt to string
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
     * Method to write an object of type TypeVectorInt to specified file
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

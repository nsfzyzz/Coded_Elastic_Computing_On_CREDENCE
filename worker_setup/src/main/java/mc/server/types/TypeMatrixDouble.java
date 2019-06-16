package mc.server.types;

import java.io.*;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Defines a TypeMatrixDouble object. <P> Provides methods to read a double matrix, matrix serialization and
 * deserialization methods, and finally standard multiplication methods.
 *
 * @author Yaoqing Yang
 * @author Malhar Chaudhari
 * @version 2.0
 */

public class TypeMatrixDouble {

    private double[][] mat;
    private int colTotal;
    private int rowTotal;

    /**
     * Constructor for class TypeMatrixDouble. Creates a TypeMatrixDouble object with all values initialized to 0.0.
     *
     * @param row Number of rows in the matrix
     * @param col Number of columns in the matrix
     */
    public TypeMatrixDouble(int row, int col) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = new double[row][col];
    }

    /**
     * Constructor for class TypeMatrixDouble. Creates a TypeMatrixDouble object with all values initialized using
     * matIn[][] input.
     *
     * @param row   Number of rows in the matrix
     * @param col   Number of columns in the matrix
     * @param matIn A double[][] two dimensional array from which the matrix is initialized
     */
    public TypeMatrixDouble(int row, int col, double[][] matIn) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = matIn;
    }

    /**
     * Constructor for class TypeMatrixDouble. Creates a TypeMatrixDouble object with all values initialized to random
     * values between randStart and randEnd inputs.
     *
     * @param row       Number of rows in the matrix
     * @param col       Number of columns in the matrix
     * @param randStart Double random start value
     * @param randEnd   Double random end value
     */
    public TypeMatrixDouble(int row, int col, double randStart, double randEnd) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = new double[row][col];

        for (int i = 0; i < row; i++) {
            for (int j = 0; j < col; j++) {
                this.mat[i][j] = ThreadLocalRandom.current().nextDouble(randStart, randEnd+1);
            }
        }

    }

    /**
     * Constructor for class TypeMatrixDouble. Creates a TypeMatrixDouble object with values read from the specified
     * filepath.
     *
     * @param row      Number of rows in the matrix
     * @param col      Number of columns in the matrix
     * @param filepath Path to the file from which the matrix is to be read
     * @param colSep   The column separator used to separate column elements in the file. Rows are assumed to be
     *                 separated by newline <code>\n</code>
     */
    public TypeMatrixDouble(int row, int col, String filepath, String colSep) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = new double[row][col];

        try {
            BufferedReader brMat = new BufferedReader(new FileReader(filepath));
            String rowLine;
            int i = 0;

            while ((rowLine = brMat.readLine()) != null && (i < row)) {
                String rowLineArr[] = rowLine.trim().split(colSep);
                for (int j = 0; j < col; j++) {
                    this.mat[i][j] = Double.parseDouble(rowLineArr[j]);
                }
                i++;
            }

            brMat.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Constructor for class TypeMatrixDouble. Creates a TypeMatrixDouble object using an input data vector
     *
     * @param row Number of rows in the matrix
     * @param col Number of columns in the matrix
     * @param vectIn The input data vector
     */

    public TypeMatrixDouble(int row, int col, TypeVectorDouble vectIn) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = new double[row][col];

        double[] vectInArray = vectIn.GetVect();

        int pos = 0;
        for (int i=0; i<this.rowTotal;i++) {
            for (int j=0;j<this.colTotal;j++) {
                this.mat[i][j] = vectInArray[pos];
                pos += 1;
            }
        }
    }

    /**
     * Returns the data of the matrix as a double array
     */

    public double[][] GetMat() {
        return this.mat;
    }

    /**
     * Method for constructing one row of the matrix
     *
     * @param row_ind Index of the row
     * @return Returns a TypeVectorDouble object as one row of the matrix.
     */

    public TypeVectorDouble GetRow(int row_ind) {

        double[] row = new double[this.colTotal];

        System.arraycopy(this.mat[row_ind], 0, row, 0, this.mat[row_ind].length);

        return new TypeVectorDouble(this.colTotal, row);
    }

    /**
     * Method for matrix vector multiplication
     *
     * @param vectIn Object of type TypeVectorDouble to be multiplied with this matrix
     * @param startInd The starting row index of the matrix-vector multiplication
     * @param numRow The number of rows that should be multiplied
     * @return prodVector
     * matrix vector multiplication
     */

    public double[] matVectMult_selected(TypeVectorDouble vectIn, int startInd, int numRow) {

        double[] prodVector = new double[numRow];

        for (int i = 0; i < numRow; i++) {

            int mat_row_ind = (startInd +i)%this.rowTotal;

            prodVector[i] = this.GetRow(mat_row_ind).vectDotProd(vectIn);

        }

        return prodVector;
    }

    /**
     * Method for generating random data at the worker nodes
     * Note that this is only for the purpose of simulation
     * In reality, the data should be downloaded from some file systems or from the cloud
     *
     * @param workNum The index of the worker
     * @param generator_matrix The generator matrix obtained from the master node
     * @param rowSize The number of rows that needs to be generated
     * @param colSize The number of cols that needs to be generated
     * @return Returns an double array that contains the generated data
     */

    public double[][] generate_data(int workNum, double[][] generator_matrix, int rowSize, int colSize) {

        // generate the all-one data
        double sum = 0;
        for (int i=0; i<10; i++) { sum = sum + generator_matrix[workNum][i]; }
        double[][] data = new double[rowSize][colSize];
        for (int i=0; i<rowSize; i++) {
            for (int j=0; j<colSize; j++) {
                data[i][j] = sum;
            }
        }

        return data;
    }

    /**
     * Method to deserialize string to an object of type TypeMatrixDouble
     *
     * @param matIn  Serialized matrix as a string
     * @param rowSep Character separator used to separate matrix rows
     * @param colSep Character separator used to separate matrix column elements
     */
    public void deserialize(String matIn, String rowSep, String colSep) {
        String[] rows = matIn.trim().split(rowSep);

        for (int i = 0; i < rows.length; i++) {
            String[] rowArr = rows[i].trim().split(colSep);
            for (int j = 0; j < rowArr.length; j++) {
                this.mat[i][j] = Double.parseDouble(rowArr[j]);
            }
        }
    }

    /**
     * Method for serializing object TypeMatrixDouble to string
     *
     * @param rowSep Character separator to be used to separate matrix rows
     * @param colSep Character separator to be used to separate matrix column elements
     * @return Returns a string serialized using the given column and row separators
     */
    public String serialize(String rowSep, String colSep) {
        StringBuilder matBuilder = new StringBuilder();

        for (int i = 0; i < this.rowTotal; i++) {
            for (int j = 0; j < this.colTotal; j++) {
                matBuilder.append(this.mat[i][j]).append(colSep);
            }
            matBuilder.deleteCharAt(matBuilder.length() - 1).append(rowSep);
        }

        return matBuilder.toString().trim();
    }

    /**
     * Method to write an object of type TypeMatrixDouble to specified file
     *
     * @param fpath  The full path to the file where the matrix is to be written
     * @param colSep Character separator to be used to separate matrix column elements
     * @param rowSep Character separator to be used to separate matrix rows
     * @throws IOException if writing to file fails
     */
    public void writeMatToFile(String fpath, String colSep, String rowSep) throws IOException {
        PrintWriter matWriter = new PrintWriter(new FileWriter(fpath));
        for (int i = 0; i < rowTotal; i++) {
            for (int j = 0; j < colTotal; j++) {
                matWriter.print(mat[i][j] + colSep);
            }
            matWriter.print(rowSep);
        }
        matWriter.close();
    }
}

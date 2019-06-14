package mc.server.types;

import java.io.*;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Defines a TypeMatrixInteger object. <P> Provides methods to read an Integer matrix, matrix serialization and
 * deserialization methods, and finally standard multiplication methods.
 *
 * @author Malhar Chaudhari
 * @version 1.0
 */

public class TypeMatrixInt {

    int[][] mat;
    int colTotal;
    private int rowTotal;

    /**
     * Constructor for class TypeMatrixInt. Creates a TypeMatrixInt object with all values initialized to 0.
     *
     * @param row Number of rows in the matrix
     * @param col Number of columns in the matrix
     */
    public TypeMatrixInt(int row, int col) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = new int[row][col];
    }

    /**
     * Constructor for class TypeMatrixInt. Creates a TypeMatrixInt object with all values initialized using matIn[][]
     * input.
     *
     * @param row   Number of rows in the matrix
     * @param col   Number of columns in the matrix
     * @param matIn An int[][] two dimensional array from which the matrix is initialized
     */
    public TypeMatrixInt(int row, int col, int[][] matIn) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = matIn;
    }

    /**
     * Constructor for class TypeMatrixInt. Creates a TypeMatrixInt object with all values initialized to random values
     * between randStart and randEnd inputs.
     *
     * @param row       Number of rows in the matrix
     * @param col       Number of columns in the matrix
     * @param randStart Integer random start value
     * @param randEnd   Integer random end value
     */
    public TypeMatrixInt(int row, int col, int randStart, int randEnd) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = new int[row][col];

        for (int i = 0; i < row; i++) {
            for (int j = 0; j < col; j++) {
                this.mat[i][j] = ThreadLocalRandom.current().nextInt(randStart, randEnd + 1);
            }
        }

    }

    /**
     * Constructor for class TypeMatrixInt. Creates a TypeMatrixInt object with values read from the specified
     * filepath.
     *
     * @param row      Number of rows in the matrix
     * @param col      Number of columns in the matrix
     * @param filepath Path to the file from which the matrix is to be read
     * @param colSep   The column separator used to separate column elements in the file. Rows are assumed to be
     *                 separated by newline <code>\n</code>
     */
    public TypeMatrixInt(int row, int col, String filepath, String colSep) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = new int[row][col];

        try {
            BufferedReader brMat = new BufferedReader(new FileReader(filepath));
            String rowLine;
            int i = 0;

            while ((rowLine = brMat.readLine()) != null && (i < row)) {
                String rowLineArr[] = rowLine.trim().split(colSep);
                for (int j = 0; j < col; j++) {
                    this.mat[i][j] = Integer.parseInt(rowLineArr[j]);
                }
                i++;
            }

            brMat.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Method for matrix vector multiplication
     *
     * @param vectIn Object of type TypeVectorInt to be multiplied with this
     *               matrix
     * @return Returns an object of type TypeVectorInt as the result of matrix
     * vector multiplication
     */
    public int[] matVectMult(TypeVectorInt vectIn) {
        int rowSum = 0;
        int[] prodVector = new int[this.rowTotal];

        for (int i = 0; i < this.rowTotal; i++) {
            for (int j = 0; j < this.colTotal; j++) {
                rowSum += this.mat[i][j] * vectIn.vect[j];
            }
            prodVector[i] = rowSum;
            rowSum = 0;
        }

        return prodVector;
    }

    /**
     * Method for matrix matrix multiplication
     *
     * @param matIn Object of type TypeMatrixInt to be multiplied with this matrix
     * @return Returns an object of type TypeMatrixInt as the result of matrix
     * matrix multiplication
     */
    public int[][] matMatMult(TypeMatrixInt matIn) {
        int rowSum = 0;
        int[][] prodMatrix = new int[this.rowTotal][matIn.colTotal];

        for (int i = 0; i < matIn.colTotal; i++) {
            for (int j = 0; j < this.rowTotal; j++) {
                for (int k = 0; k < this.colTotal; k++) {
                    rowSum += this.mat[j][k] * matIn.mat[k][i];
                }
                prodMatrix[j][i] = rowSum;
                rowSum = 0;
            }
        }

        return prodMatrix;
    }

    /**
     * Method to deserialize string to an object of type TypeMatrixInt
     *
     * @param matIn  Serialized matrix as a string
     * @param rowSep Character separator used to separate matrix rows
     * @param colSep Character separator to be used to separate matrix column elements
     */
    public void deserialize(String matIn, String rowSep, String colSep) {
        String[] rows = matIn.trim().split(rowSep);

        for (int i = 0; i < rows.length; i++) {
            String[] rowArr = rows[i].trim().split(colSep);
            for (int j = 0; j < rowArr.length; j++) {
                this.mat[i][j] = Integer.parseInt(rowArr[j]);
            }
        }
    }

    /**
     * Method for serializing object TypeMatrixInt to string
     *
     * @param rowSep Character separator used to separate matrix rows
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
     * Method to write an object of type TypeMatrixInt to specified file
     *
     * @param fpath  The full path to the file where the matrix is to be written
     * @param colSep Character separator to be used to separate matrix column elements
     * @param rowSep Character separator used to separate matrix rows
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

package mc.server.types;

import java.io.*;
import java.util.concurrent.ThreadLocalRandom;
import mc.server.types.TypeVectorDouble;
import org.apache.commons.math3.linear.Array2DRowRealMatrix;
import org.apache.commons.math3.linear.ArrayRealVector;
import org.apache.commons.math3.linear.DecompositionSolver;
import org.apache.commons.math3.linear.LUDecomposition;
import org.apache.commons.math3.linear.RealMatrix;
import org.apache.commons.math3.linear.RealVector;

/**
 * Defines a TypeMatrixDouble object. <P> Provides methods to read a double matrix, matrix serialization and
 * deserialization methods, and finally standard multiplication methods.
 *
 * @author Yaoqing Yang
 * @author Malhar Chaudhari
 * @version 2.0
 */

public class TypeMatrixDouble {

    double[][] mat;
    int colTotal;
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
     * Constructor for class TypeMatrixDouble. Creates a TypeMatrixDouble object with an input data vector
     *
     * @param row   Number of rows in the matrix
     * @param col   Number of columns in the matrix
     * @param vectIn The input data vector
     */
    public TypeMatrixDouble(int row, int col, double[] vectIn) {
        this.rowTotal = row;
        this.colTotal = col;
        this.mat = new double[row][col];

        int pos = 0;
        for (int i=0; i<this.rowTotal;i++) {
            for (int j=0;j<this.colTotal;j++) {
                this.mat[i][j] = vectIn[pos];
                pos += 1;
            }
        }
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

    public double[][] GetMat() {
        return this.mat;
    }

    /**
     * Method for matrix vector multiplication
     *
     * @param vectIn Object of type TypeVectorDouble to be multiplied with this
     *               matrix
     * @return Returns an object of type TypeVectorDouble as the result of
     * matrix vector multiplication
     */
    public double[] matVectMult(TypeVectorDouble vectIn) {
        double rowSum = 0;
        double[] prodVector = new double[this.rowTotal];

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
     * Method for converting a matrix to a data vector
     *
     * @return Returns an object of type TypeVectorDouble that contains the data
     */
    public double[] toVect() {
        double[] vect = new double[this.rowTotal*this.colTotal];
        int pos = 0;
        for (int i=0; i<this.rowTotal;i++) {
            for (int j=0;j<this.colTotal;j++) {
                vect[pos] = this.mat[i][j];
                pos += 1;
            }
        }
        return vect;
    }


    /**
     * Method for matrix matrix multiplication
     *
     * @param matIn Object of type TypeMatrixDouble to be multiplied with this
     *              matrix
     * @return Returns a double array as result
     */
    public double[][] matMatMult(TypeMatrixDouble matIn) {
        double rowSum = 0;
        double[][] prodMatrix = new double[this.rowTotal][matIn.colTotal];

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
     * Method for matrix matrix multiplication
     *
     * @param matIn Object of type TypeMatrixDouble to be multiplied with this
     *              matrix
     * @return Returns an object of type TypeMatrixDouble as the result of
     * matrix matrix multiplication
     */
    public TypeMatrixDouble matMatMultGiveMat(TypeMatrixDouble matIn) {
        double rowSum = 0;
        double[][] prodMatrix = new double[this.rowTotal][matIn.colTotal];

        for (int i = 0; i < matIn.colTotal; i++) {
            for (int j = 0; j < this.rowTotal; j++) {
                for (int k = 0; k < this.colTotal; k++) {
                    rowSum += this.mat[j][k] * matIn.mat[k][i];
                }
                prodMatrix[j][i] = rowSum;
                rowSum = 0;
            }
        }

        return new TypeMatrixDouble(this.rowTotal, matIn.colTotal, prodMatrix);
    }

    /**
     * Method for returning the number of cols
     */
    public int num_col() {

        int num_col = this.colTotal;
        return num_col;
    }

    /**
     * Method for setting a particular row
     */
    public void set_row(int row_ind, TypeVectorDouble vec) {
        
        for (int j = 0; j < this.colTotal; j++) {
            this.mat[row_ind][j] = vec.vect[j];
        }

    }

    /**
     * Method for setting a particular row
     */
    public void set_row(int row_ind, TypeMatrixDouble matIn, int in_ind) {
        
        if (matIn.num_col()!=this.colTotal) {
            throw new ArithmeticException("The matrix being set does not match in size with the input!");

        }
        for (int j = 0; j < this.colTotal; j++) {
            this.mat[row_ind][j] = matIn.mat[in_ind][j];
        }

    }

    /**
     * Method for inverting a matrix by calling the org.apache.commons.math3.linear.RealMatrix
     */
    public TypeMatrixDouble matInv() {

        if (this.rowTotal != this.colTotal) {
            throw new ArithmeticException("The input matrix is not square and does not have inverse!");
        }

        double [][] rhs = new double[this.rowTotal][this.rowTotal];
        for (int i=0; i<this.rowTotal; i++) {
            rhs[i][i] = 1.0;
        }

        // Solving AB = I for given A
        RealMatrix A = new Array2DRowRealMatrix(this.mat);
        //System.out.println("Input A: " + A);
        DecompositionSolver solver = new LUDecomposition(A).getSolver();

        RealMatrix I = new Array2DRowRealMatrix(rhs);
        RealMatrix B = solver.solve(I);
        //System.out.println("Inverse B: " + B);

        TypeMatrixDouble invMat = new TypeMatrixDouble(this.rowTotal, this.colTotal, B.getData());
        return invMat;
    }


    /**
     * Method for getting a subrow of a matrix
     */
    public TypeVectorDouble sub_row(int row_ind, int start_id, int length) {

        TypeVectorDouble subvector = new TypeVectorDouble(length);
        if (start_id + length > this.num_col()) {
            throw new ArithmeticException("The subvector went out of index range!");
        }
        for (int j=0; j<length; j++) {
            subvector.vect[j] = this.mat[row_ind][start_id+j];
        }
        return subvector;
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

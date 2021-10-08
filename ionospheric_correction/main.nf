#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Generate predict
process frion_predict {
    container = params.IONOSPHERIC_CORRECTION_IMAGE
    containerOptions = '--bind /mnt/shared:/mnt/shared'

    input:
        val cubes

    output:
        val "${params.FRION_PREDICT_OUTFILE}", emit: file

    // The frion_predict tool takes an input file (a single FITS cube),
    // and returns a text file containing the prediction for the ionospheric
    // Faraday rotation.
    script:
        """
        frion_predict -F ${params.FRION_Q_INPUT_CUBE} -s ${params.FRION_PREDICT_OUTFILE}
        """
}

// Apply correction
process frion_correct {
    container = params.IONOSPHERIC_CORRECTION_IMAGE
    containerOptions = '--bind /mnt/shared:/mnt/shared'

    input:
        val predict_file

    // The frion_correct tool applies a correction to the Stokes Q and U cubes,
    // using the prediction file from the predict step. The output is two
    // new FITS cubes with the correction applied.
    // The call sequence is: 
    // frion_correct -L $INPUT_Q_CUBE $INPUT_U_CUBE $PREDICT_FILE $OUTPUT_Q_CUBE $OUTPUT_U_CUBE
    // (The -L flag enables a new large-file mode that reduces the memory footprint).
    script:
        """
        frion_correct -L ${params.FRION_Q_INPUT_CUBE} ${params.FRION_U_INPUT_CUBE} $predict_file \
            ${params.FRION_Q_OUTPUT_CUBE} ${params.FRION_U_OUTPUT_CUBE}
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------
// The input should be a Stokes Q cube (FITS file) and a Stokes U cube (a matched
//  set from the same observation).
// The output is a similar pair of cubes with the ionospheric correction applied
//  plus a text file containing the prediction.
// Other cubes from the same observation (Stokes I, Stokes V) should not be
//  affected by this step.

workflow ionospheric_correction {
    take: cubes
    
    main:
        frion_predict(cubes)
        frion_correct(frion_predict.out.file)
}

// ----------------------------------------------------------------------------------------
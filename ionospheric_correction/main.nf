#!/usr/bin/env nextflow
​
nextflow.enable.dsl = 2
​
// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------
​
// Generate prediction
process predict {
    container = params.FRION_IMAGE
    containerOptions = '--bind /mnt/shared:/mnt/shared'
​
    input:
        val cubes
​
    output:
        file "${params.WORKDIR}/${params.FRION_PREDICT_OUTFILE}" into predict_file
​
​
    // The frion_predict tool takes an input file (a single FITS cube),
    // and returns a text file containing the prediction for the ionospheric
    // Faraday rotation.
    script:
        """
        frion_predict -F "$cubes[0]" \
            -s ${params.WORKDIR}/${params.FRION_PREDICT_OUTFILE}
        """
}
​
// Apply correction
process correct {
    containerOptions = '--bind /mnt/shared:/mnt/shared'
​
    input:
        val cubes
        file predict_file
    
    output:
        val corrected_cubes emit: ???
​
    // The frion_correct tool applies a correction to the Stokes Q and U cubes,
    // using the prediction file from the predict step. The output is two
    // new FITS cubes with the correction applied.
    // The call sequence is: 
    // frion_correct -L $INPUT_Q_CUBE $INPUT_U_CUBE $PREDICT_FILE $OUTPUT_Q_CUBE $OUTPUT_U_CUBE
    // (The -L flag enables a new large-file mode that reduces the memory footprint).
    script:
        """
        frion_correct -L "$cubes" $predict_file "${cubes/.fits/.frion.fits}"
        corrected_cubes = "${cubes/.fits/.frion.fits}"
        """
}
​
// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------
// The input should be a Stokes Q cube (FITS file) and a Stokes U cube (a matched
//  set from the same observation).
// The output is a similar pair of cubes with the ionospheric correction applied
//  plus a text file containing the prediction.
// Other cubes from the same observation (Stokes I, Stokes V) should not be
//  affected by this step.
​
workflow frion_correct {
    take: cubes
​
    main:
        predict(cubes.collect())
        correct(cubes.collect(),predict_file)
    
    emit:
        new_cubes = correct.out.mosaicked_cube
        predict_file = predict.out.predict_file
}
​
// ----------------------------------------------------------------------------------------
​
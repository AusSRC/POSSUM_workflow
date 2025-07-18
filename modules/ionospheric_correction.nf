#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process observation_start_time {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val q_cube

    output:
        stdout emit: time

    script:
        """
        #!python3
        from astropy.io import fits

        hdu = fits.open("${q_cube}")
        header = hdu[0].header
        print(header["DATE"], end="")
        """
}

process observation_end_time {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val q_cube

    output:
        stdout emit: time

    script:
        """
        #!python3

        from astropy.io import fits
        from astropy.time import Time
        import astropy.units as u

        hdu = fits.open("${q_cube}")
        header = hdu[0].header
        start = Time(header["DATE"])
        duration = float(header["DURATION"])
        end = start + duration * u.second

        print(end.value, end="")
        """
}

// Generate predict
process frion_predict {
    container = params.IONOSPHERIC_CORRECTION_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} --bind /home:/home"

    input:
        val q_cube
        val start_time
        val end_time

    output:
        val "${params.WORKDIR}/sbid_processing/${params.SBID}/${params.FRION_PREDICT_OUTFILE}", emit: file

    // The frion_predict tool takes an input file (a single FITS cube),
    // and returns a text file containing the prediction for the ionospheric
    // Faraday rotation.
    script:
        """
        #!/bin/bash

        frion_predict \
            -F $q_cube \
            -s ${params.WORKDIR}/sbid_processing/${params.SBID}/${params.FRION_PREDICT_OUTFILE} \
            -t "ASKAP" \
            -d $start_time $end_time
        """
}

// Apply corrections
process frion_correct {
    container = params.IONOSPHERIC_CORRECTION_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val q_cube
        val u_cube
        val predict_file

    output:
        val "${params.WORKDIR}/sbid_processing/${params.SBID}/${params.FRION_Q_CUBE_FILENAME}", emit: q_cube_output
        val "${params.WORKDIR}/sbid_processing/${params.SBID}/${params.FRION_U_CUBE_FILENAME}", emit: u_cube_output

    // The frion_correct tool applies a correction to the Stokes Q and U cubes,
    // using the prediction file from the predict step. The output is two
    // new FITS cubes with the correction applied.
    // The call sequence is:
    // frion_correct -L $INPUT_Q_CUBE $INPUT_U_CUBE $PREDICT_FILE $OUTPUT_Q_CUBE $OUTPUT_U_CUBE
    // (The -L flag enables a new large-file mode that reduces the memory footprint).
    script:
        """
        #!/bin/bash

        frion_correct \
            -L \
            -o $q_cube $u_cube $predict_file \
            ${params.WORKDIR}/sbid_processing/${params.SBID}/${params.FRION_Q_CUBE_FILENAME} \
            ${params.WORKDIR}/sbid_processing/${params.SBID}/${params.FRION_U_CUBE_FILENAME}
        """
}

process frion_corr_cubes_exist {
    input:
        val q_cube
        val u_cube

    output:
        val exists, emit: exists
        val q_cube_corr, emit: q_cube_corr
        val u_cube_corr, emit: u_cube_corr

    exec:
        q_cube_corr = "${params.WORKDIR}/sbid_processing/${params.SBID}/${params.FRION_Q_CUBE_FILENAME}"
        u_cube_corr = "${params.WORKDIR}/sbid_processing/${params.SBID}/${params.FRION_U_CUBE_FILENAME}"
        q_corr_exists = new File(q_cube_corr).exists();
        u_corr_exists = new File(u_cube_corr).exists();
        exists = q_corr_exists && u_corr_exists;
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
    take:
        q_cube
        u_cube

    main:
        frion_corr_cubes_exist(q_cube, u_cube)
        if ( frion_corr_cubes_exist.out.exists == true ) {
            println "ionospheric corrected cubes exist, skipping"
            q_cube_corr = frion_corr_cubes_exist.out.q_cube_corr
            u_cube_corr = frion_corr_cubes_exist.out.u_cube_corr
        } else {
            observation_start_time(q_cube)
            observation_end_time(q_cube)
            frion_predict(q_cube, observation_start_time.out.time, observation_end_time.out.time)
            frion_correct(q_cube, u_cube, frion_predict.out.file)
            q_cube_corr = frion_correct.out.q_cube_output
            u_cube_corr = frion_correct.out.u_cube_output
        }

    emit:
        q_cube_corr
        u_cube_corr
}

// ----------------------------------------------------------------------------------------

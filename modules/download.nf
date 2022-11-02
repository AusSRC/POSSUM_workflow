#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process check {
    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash
        # Ensure working directory exists
        [ ! -d ${params.WORKDIR}/${params.SBID} ] && mkdir ${params.WORKDIR}/${params.SBID}
        exit 0
        """
}

process casda_download {
    container = params.CASDA_DOWNLOAD_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val sbid
        val check

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        python3 /app/casda_download.py \
            -i $sbid \
            -o ${params.WORKDIR}/${params.SBID} \
            -p POSSUM \
            -c ${params.CASDA_CREDENTIALS}
        """
}

process get_files {
    executor = 'local'

    input:
        val check

    output:
        val i_cube, emit: i_cube
        val q_cube, emit: q_cube
        val u_cube, emit: u_cube
        val weights, emit: weights

    exec:
        i_cube = file("${params.WORKDIR}/${params.SBID}/image.restored.i.*.contcube.fits")
        q_cube = file("${params.WORKDIR}/${params.SBID}/image.restored.q.*.contcube.fits")
        u_cube = file("${params.WORKDIR}/${params.SBID}/image.restored.u.*.contcube.fits")
        weights = file("${params.WORKDIR}/${params.SBID}/weights.i.*.contcube.fits")
}

// ----------------------------------------------------------------------------------------

workflow download {
    take: sbid

    main:
        check()
        casda_download(sbid, check.out.stdout)
        get_files(casda_download.out.stdout)

    emit:
        i_cube = get_files.out.i_cube
        q_cube = get_files.out.q_cube
        u_cube = get_files.out.u_cube
        weights = get_files.out.weights
}

// ----------------------------------------------------------------------------------------

#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process check {
    input:
        val sbid

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash
        [ ! -d ${params.WORKDIR}/sbid_processing/$sbid/${params.EVALUATION_FILES_DIR} ] && mkdir -p ${params.WORKDIR}/sbid_processing/$sbid/${params.EVALUATION_FILES_DIR}

        exit 0
        """
}

process download {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return 'retry' }
    maxErrors 10

    input:
        val check

    output:
        val "${params.WORKDIR}/sbid_processing/${params.SBID}/${params.EVALUATION_FILES_DIR}", emit: evaluation_files

    script:
        """
        #!/bin/bash

        python3 /app/download_evaluation_files.py \
            -s ${params.SBID} \
            -p AS203 \
            -o ${params.WORKDIR}/sbid_processing/${params.SBID}/${params.EVALUATION_FILES_DIR} \
            -c ${params.CASDA_CREDENTIALS}

        python3 /app/download_evaluation_files.py \
            -s ${params.SBID} \
            -p AS202 \
            -o ${params.WORKDIR}/sbid_processing/${params.SBID}/${params.EVALUATION_FILES_DIR} \
            -c ${params.CASDA_CREDENTIALS}

        python3 /app/download_evaluation_files.py \
            -s ${params.SBID} \
            -p AS201 \
            -o ${params.WORKDIR}/sbid_processing/${params.SBID}/${params.EVALUATION_FILES_DIR} \
            -c ${params.CASDA_CREDENTIALS}
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow get_evaluation_files {
    take:
        sbid

    main:
        check(sbid)
        download(check.out.stdout)

    emit:
        evaluation_files = download.out.evaluation_files
}

// ----------------------------------------------------------------------------------------

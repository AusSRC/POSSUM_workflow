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
        [ ! -d ${params.WORKDIR}/$sbid/${params.EVALUATION_FILES_DIR} ] && mkdir -p ${params.WORKDIR}/$sbid/${params.EVALUATION_FILES_DIR}

        exit 0
        """
}

process download {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val check

    output:
        val "${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR}", emit: evaluation_files

    script:
        """
        python3 /app/download_evaluation_files.py \
            -s ${params.SBID} \
            -p AS103 \
            -o ${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR} \
            -c ${params.CASDA_CREDENTIALS}
        """
}

process extract {
    input:
        val check

    output:
        stdout emit: stdout

    script:
        """
        #!/usr/bin/python3
        import os
        import glob

        files = glob.glob("${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR}/" + "*metadata*.tar")
        for f in files:
            os.system(f"tar -xvf {f} -C ${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR}")
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
        extract(download.out.evaluation_files)

    emit:
        evaluation_files = download.out.evaluation_files
        metadata_dir = extract.out.stdout
}

// ----------------------------------------------------------------------------------------
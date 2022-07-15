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
        [ ! -d ${params.WORKDIR}/${params.RUN_NAME} ] && mkdir ${params.WORKDIR}/${params.RUN_NAME}
        exit 0
        """
}

// ----------------------------------------------------------------------------------------

workflow setup {
    main:
        check()

    emit:
        check = check.out.stdout
}

// ----------------------------------------------------------------------------------------

#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process tiling_pre_check {
    input:
        val config

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check config file
        [ ! -f $config ] && { echo "Configuration file does not exist"; exit 1; }

        exit 0
        """
}

process run_sky_tiling {
    container = params.SKY_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val config
        val check

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/pyCASATILE.py -j $config
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow sky_tiling {
    take: config

    main:
        tiling_pre_check(config)
        run_sky_tiling(config, tiling_pre_check.out.stdout)
}

// ----------------------------------------------------------------------------------------

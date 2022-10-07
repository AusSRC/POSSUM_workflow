#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process tiling_pre_check {
    input:
        val image_cube
        val tiling_map

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check image_cube file
        [ ! -f $image_cube ] && { echo "Image cube file does not exist"; exit 1; }

        # Check tiling map file
        [ ! -f $tiling_map ] && { echo "Tiling map file does not exist"; exit 1; }

        # Check output directory
        [ ! -d ${params.TILING_OUTPUT_DIR} ] && mkdir -p ${params.TILING_OUTPUT_DIR}

        # Check config file
        [ ! -f ${params.TILING_CONFIG} ] && { echo "Configuration file does not exist"; exit 1; }

        exit 0
        """
}

process run_tiling {
    container = params.SKY_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val tiling_map
        val check

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/pyCASATILE.py \
            -i $image_cube \
            -m $tiling_map \
            -o ${params.TILING_OUTPUT_DIR} \
            -j ${params.TILING_CONFIG}
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow tiling {
    take:
        image_cube
        tiling_map

    main:
        tiling_pre_check(image_cube, tiling_map)
        run_tiling(image_cube, tiling_map, tiling_pre_check.out.stdout)
}

// ----------------------------------------------------------------------------------------

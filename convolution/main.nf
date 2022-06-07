#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Check output and header directories exist and are empty
process convolution_pre_check {
    input:
        val cube

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check image cube files exist
        [ ! -f ${cube} ] && { echo "Image cube not found"; exit 1; }

        # Check if beamlog file exists

        exit 0
        """
}

// Run Beamcon_3D for convolution
process beamcon {
    container = params.RACS_TOOLS_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val convolution_pre_check
    
    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash
        
        beamcon_3D --mode total --bmaj 13 --bmin 13 --bpa 0 -v ${image_cube}
        """
}

process beamcon_output_cube {
    input:
        val image_cube
        val beamcon
    
    output:
        stdout emit: stdout

    script:
        """
        #!python3
        import os

        input_cube = '${image_cube}'
        prefix = input_cube.rsplit('.', 1)[0]
        output_cube = f"{prefix}.total.fits"

        if not os.path.exists(output_cube):
            raise Exception("Convolution output image cube not found")

        print(output_cube, end='')
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow convolution {
    take: cube
    take: check

    main:
        convolution_pre_check(cube)
        beamcon(cube, convolution_pre_check.out.stdout)
        beamcon_output_cube(cube, beamcon.out.stdout)
    
    emit:
        cube_conv = beamcon_output_cube.out.stdout
}

// ----------------------------------------------------------------------------------------

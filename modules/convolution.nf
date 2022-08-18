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

    shell:
        '''
        # Check image cube files exist
        [ ! -f !{cube} ] && { echo "Image cube not found"; exit 1; }

        # Check if beamlog file exists
        cube=!{cube}
        path=${cube%/*}
        filename=${cube##*/}
        basename=${filename%.*}
        [ ! -f ${path}/beamlog.${basename}.txt ] && { echo "Beamlog file not found at ${path}/beamlog.${basename}.txt"; exit 1; }

        exit 0;
        '''
}

// Copy file for beamcon_3D override mode
process copy {
    input:
        val cube

    output:
        stdout emit: copy_cube

    shell:
        '''
        cube=!{cube}
        path=${cube%/*}
        filename=${cube##*/}
        basename=${filename%.*}

        # Create copy
        [ ! -f ${path}/${basename}.total.fits ] && { cp !{cube} ${path}/${basename}.total.fits; }
        [ ! -f ${path}/beamlog.${basename}.total.txt ] && { cp ${path}/beamlog.${basename}.txt ${path}/beamlog.${basename}.total.txt; }

        # Return
        echo -n ${path}/${basename}.total.fits;
        exit 0;
        '''
}

// Run Beamcon_3D for convolution
process beamcon {
    input:
        val image_cube
        val convolution_pre_check

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

	    time mpiexec singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${params.SINGULARITY_CACHEDIR}/aussrc-racstools.sif \
            beamcon_3D ${image_cube} --mode total -v --override
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
        copy(cube)
        beamcon(copy.out.copy_cube, convolution_pre_check.out.stdout)
        beamcon_output_cube(cube, beamcon.out.stdout)

    emit:
        cube_conv = beamcon_output_cube.out.stdout
}

// ----------------------------------------------------------------------------------------

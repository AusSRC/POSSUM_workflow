#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process pull_racstools_image {
    output:
        val container, emit: container

    script:
        container = "${params.SINGULARITY_CACHEDIR}/${params.RACS_TOOLS_IMAGE_NAME}.sif"
        """
        #!/bin/bash

        # check image exists
        [ ! -f ${container} ] && { singularity pull ${container} ${params.RACS_TOOLS_IMAGE}; }
        exit 0
        """
}

process extract_beamlog {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val evaluation_files

    output:
        val true, emit: done

    script:
        """
        python3 /app/get_file_in_compressed_folder.py \
            -p $evaluation_files \
            -f calibration-metadata-processing-logs \
            -k SpectralCube_BeamLogs/beamlog \
            -o $evaluation_files/SpectralCube_BeamLogs
        """
}

process copy_beamlog {
    input:
        val image_cube
        val evaluation_files
        val check

    output:
        val beamlog, emit: beamlog

    script:
        def cube = file(image_cube)
        def beamlog_src = file("${evaluation_files}/SpectralCube_BeamLogs/beamlog*.i.*beam00.txt").first()
        def beamlog_dest = "${cube.getParent()}/beamlog.${cube.getBaseName()}.txt"
        beamlog = file(beamlog_dest)

    if (!beamlog.exists())
        """
        #!/bin/bash

        cp $beamlog_src $beamlog_dest
        """
    else
        """
        #!/bin/bash
        echo $beamlog_dest
        """
}

process beamcon_2D {
    input:
        val image
        val container

    output:
        val true, emit: done

    script:
        file = file(image)
        """
        #!/bin/bash

        export NUMBA_CACHE_DIR="${params.NUMBA_CACHE_DIR}"
	    singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${container} \
            beamcon_2D ${image} \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            -v
        """
}

process beamcon_3D {
    input:
        val image_cube
        val beamlog
        val container

    output:
        val true, emit: done

    script:
        file = file(image_cube)
        """
        #!/bin/bash
        export NUMBA_CACHE_DIR="${params.NUMBA_CACHE_DIR}"
        singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${container} \
            beamcon_3D ${image_cube} \
            --mode total \
            --conv_mode robust \
            --suffix ${params.BEAMCON_3D_SUFFIX} \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            --cutoff ${params.CUTOFF} \
            --ncores 8 \
            --executor_type process \
            -vvv
        """

}

process conv_cube_exists {
    input:
        val image_cube

    output:
        val exists, emit: exists
        val true, emit: done

    exec:
        cube = file(image_cube)
        empty = file("${cube.getParent()}/${cube.getBaseName()}*${params.BEAMCON_3D_SUFFIX}*${cube.getExtension()}").empty
        exists = !empty
}

process get_cube_conv {
    input:
        val image_cube
        val suffix
        val check

    output:
        val cube_conv, emit: cube_conv

    exec:
        cube = file(image_cube)
        cube_conv = file("${cube.getParent()}/${cube.getBaseName()}*$suffix*${cube.getExtension()}").first()
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow conv2d {
    take:
        image_cube
        stokes

    main:
        beamcon_2D(image_cube, "${params.SINGULARITY_CACHEDIR}/${params.RACS_TOOLS_IMAGE_NAME}.sif")
        get_cube_conv(image_cube, "${params.BEAMCON_2D_SUFFIX}", beamcon_2D.out.done)

    emit:
        cube_conv = get_cube_conv.out.cube_conv
}

workflow conv3d {
    take:
        cube
        evaluation_files
        stokes

    main:
        // Check if convolved cube exists before running
        conv_cube_exists(cube)
        if ( conv_cube_exists.out.exists == true ) {
            println "convolved cube exists, skipping"
            get_cube_conv(cube, "${params.BEAMCON_3D_SUFFIX}", conv_cube_exists.out.done)
        } else {
            extract_beamlog(evaluation_files)
            copy_beamlog(cube, evaluation_files, extract_beamlog.out.done)
            beamcon_3D(cube, copy_beamlog.out.beamlog, "${params.SINGULARITY_CACHEDIR}/${params.RACS_TOOLS_IMAGE_NAME}.sif")
            get_cube_conv(cube, "${params.BEAMCON_3D_SUFFIX}", beamcon_3D.out.done)
        }

    emit:
        cube_conv = get_cube_conv.out.cube_conv
}

// ----------------------------------------------------------------------------------------

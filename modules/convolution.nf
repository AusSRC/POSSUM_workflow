#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process split_cube {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube

    output:
        stdout emit: files_str

    script:
        """
        # Make working directory
        [ ! -d ${params.WORKDIR}/sbid_processing/${params.SBID}/${params.ZERO_SPLIT_CUBE_SUBDIR} ] && mkdir -p ${params.WORKDIR}/sbid_processing/${params.SBID}/${params.ZERO_SPLIT_CUBE_SUBDIR}

        export PYTHONPATH='\$PYTHONPATH:${params.CASADATA}'

        python3 -u /app/split_cube.py \
            -i "$image_cube" \
            -o "${params.WORKDIR}/sbid_processing/${params.SBID}/${params.ZERO_SPLIT_CUBE_SUBDIR}" \
            -n ${params.NAN_TO_ZERO_NSPLIT}
        """
}

process get_split_cubes {
    input:
        val files_str

    output:
        val subcubes, emit: subcubes

    exec:
        filenames = files_str.split(',')
        subcubes = filenames.collect{ it = file("${params.WORKDIR}/sbid_processing/${params.SBID}/${params.ZERO_SPLIT_CUBE_SUBDIR}/$it") }
}

process join_split_cubes {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val check

    output:
        val output_cube, emit: output_cube

    script:
        def parent = file(image_cube).getParent()
        def basename = file(image_cube).getBaseName()
        def files = file("${params.WORKDIR}/sbid_processing/${params.SBID}/${params.ZERO_SPLIT_CUBE_SUBDIR}/*$basename*zeros*.fits")
        def file_string = files.join(' ')
        output_cube = "${parent}/${basename}.zeros.fits"

        """
        #!/bin/bash

        python3 -u /app/join_subcubes.py \
            -f $file_string \
            -o $output_cube \
            --overwrite
        """
}

process pull_racstools_image {
    output:
        val container, emit: container

    script:
        container = "${params.SINGULARITY_CACHEDIR}/racstools_latest.sif"

        """
        #!/bin/bash

        # check image exists
        [ ! -f ${container} ] && { singularity pull ${container} ${params.RACS_TOOLS_IMAGE}; }
        exit 0
        """
}

process beamcon_2D {
    input:
        val image
        val container

    output:
        stdout emit: stdout

    script:
        file = file(image)

        """
        #!/bin/bash

	export OMP_NUM_THREADS=1
        export NUMBA_CACHE_DIR="${params.NUMBA_CACHE_DIR}"

	    singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${container} \
            beamcon_2D ${image} \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            -v
        """
}

process extract_beamlog {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val evaluation_files

    output:
        stdout emit: stdout

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
        val extract

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

process beamcon_3D {
    input:
        val image_cube
        val beamlog
        val container

    output:
        stdout emit: stdout

    script:
        file = file(image_cube)

        """
        #!/bin/bash

        export MPICH_OFI_STARTUP_CONNECT=1
        export MPICH_OFI_VERBOSE=1
        export OMP_NUM_THREADS=1
        export NUMBA_CACHE_DIR="${params.NUMBA_CACHE_DIR}"

	    srun --export=ALL --mpi=pmi2 -n 36 singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${container} \
            beamcon_3D ${image_cube} \
            --mode total \
            --conv_mode robust \
            --suffix ${params.BEAMCON_3D_SUFFIX} \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            --cutoff ${params.CUTOFF} \
            -vvv
        """
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
        cube_conv = file("${cube.getParent()}/${cube.getBaseName()}*${suffix}*${cube.getExtension()}").first()
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow conv2d {
    take:
        image_cube
        stokes

    main:
        pull_racstools_image()
        beamcon_2D(image_cube, pull_racstools_image.out.container)
        get_cube_conv(image_cube, "${params.BEAMCON_2D_SUFFIX}", beamcon_2D.out.stdout)

    emit:
        cube_conv = get_cube_conv.out.cube_conv
}

workflow conv3d {
    take:
        cube
        evaluation_files
        stokes

    main:
        pull_racstools_image()
        extract_beamlog(evaluation_files)
        copy_beamlog(cube, evaluation_files, extract_beamlog.out.stdout)
        beamcon_3D(cube, copy_beamlog.out.beamlog, pull_racstools_image.out.container)
        get_cube_conv(cube, "${params.BEAMCON_3D_SUFFIX}", beamcon_3D.out.stdout)

    emit:
        cube_conv = get_cube_conv.out.cube_conv
}

// ----------------------------------------------------------------------------------------

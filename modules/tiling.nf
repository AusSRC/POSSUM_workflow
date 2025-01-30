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
        val stokes

    output:
        stdout emit: files_str

    script:
        """
        python3 -u /app/fits_split.py \
            --input "$image_cube" \
            --output "${params.WORKDIR}/sbid_processing/${params.SBID}/${params.SPLIT_CUBE_SUBDIR}/$stokes" \
            --splits ${params.NSPLIT}
        """
}

process get_split_cubes {
    input:
        val files_str
        val stokes

    output:
        val subcubes, emit: subcubes

    exec:
        def pattern = ~/.*fits$/
        subcubes = new File("${params.WORKDIR}/sbid_processing/${params.SBID}/${params.SPLIT_CUBE_SUBDIR}/$stokes").listFiles((FileFilter) { it.isFile() && it.getName().matches(pattern) }).collect{it.getAbsolutePath()}
}

process run_hpx_tiling {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val obs_id
        val image_cube
        val pixel_map_csv
        val stokes
        val type

    output:
        val image_cube, emit: image_cube_out

    script:
        prefix = file(image_cube).getBaseName()
        if (type == 'mfs') {
            output = "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$obs_id/mfs/$stokes"
        }
        else {
            output = "${params.WORKDIR}/sbid_processing/${params.SBID}/tiles/$obs_id/$stokes/"
        }

        """
        #!/bin/bash
        python3 -u /app/casa_tiling.py \
            -i $obs_id \
            -c $image_cube \
            -m $pixel_map_csv \
            -o $output \
            -t ${params.HPX_TILE_TEMPLATE} \
            -p $prefix
        """
}

process get_unique_pixel_ids {
    input:
        val check
        val obs_id
        val stokes

    output:
        val pixel_id, emit: pixel_id

    exec:
        pixel_id = file("${params.WORKDIR}/sbid_processing/${params.SBID}/tiles/$obs_id/$stokes/*.fits")
            .collect{ path -> (path.baseName.split('-')[-1] =~ /\d+/).findAll().first() }
            .unique()
}

process join_split_hpx_tiles {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val pixel_id
        val obs_id
        val stokes

    output:
        val hpx_tile, emit: hpx_tile
        val true, emit: ready

    script:
        files = file("${params.WORKDIR}/sbid_processing/${params.SBID}/tiles/$obs_id/$stokes/*${obs_id}-${pixel_id}*.fits")
        file_string = files.join(' ')
        hpx_tile = file("${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$obs_id/survey/$stokes/${params.HPX_TILE_PREFIX}.${obs_id}.${pixel_id}.${stokes}.fits")

        """
        #!/bin/bash

        python3 -u /app/join_subcubes.py \
            -f $file_string \
            -o $hpx_tile \
            --overwrite
        """
}

process repair_tiles {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val ready
        val obs_id
        val stokes

    output:
        val true, emit: ready

    script:
        """
        #!/bin/bash

        python3 /app/repair_incomplete_tiles.py \
            "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$obs_id/survey/$stokes/" \
            --overwrite
        """
}

// ----------------------------------------------------------------------------------------
// Workflows
// ----------------------------------------------------------------------------------------

workflow split_casa_tiling {
    take:
        obs_id
        image_cube
        pixel_map
        stokes

    main:
        split_cube(image_cube, stokes)

        get_split_cubes(split_cube.out.files_str, stokes)

        run_hpx_tiling(obs_id,
                       get_split_cubes.out.subcubes.flatten(),
                       pixel_map,
                       stokes,
                       "survey")

        get_unique_pixel_ids(run_hpx_tiling.out.image_cube_out.collect(),
                             obs_id,
                             stokes)

        join_split_hpx_tiles(get_unique_pixel_ids.out.pixel_id.flatten(),
                             obs_id,
                             stokes)

        repair_tiles(join_split_hpx_tiles.out.ready.collect(),
                     obs_id,
                     stokes)

    emit:
        ready = repair_tiles.out.ready
}

workflow split_tiling {
    take:
        sbid
        obs_id
        image_cube
        tile_map
        stokes

    main:
        split_casa_tiling(obs_id, image_cube, tile_map, stokes)

    emit:
        ready = split_casa_tiling.out.ready
}

workflow tiling {
    take:
        sbid
        obs_id
        image_cube
        tile_map
        stokes

    main:
        run_hpx_tiling(obs_id,
                       image_cube,
                       tile_map,
                       stokes,
                       'mfs')

    emit:
        ready = run_hpx_tiling.out.image_cube_out
}

// ----------------------------------------------------------------------------------------

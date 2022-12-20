#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process check {
    input:
        val sbid
        val image_cube
        val stokes

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check important files
        [ ! -f $image_cube ] && { echo "Image cube file does not exist"; exit 1; }
        [ ! -f ${params.HPX_TILE_CONFIG} ] && { echo "HEALPIX tiling configuration file does not exist"; exit 1; }

        # Check working directories
        [ ! -d ${params.WORKDIR}/$sbid ] && mkdir -p ${params.WORKDIR}/$sbid
        [ ! -d ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR} ] && mkdir -p ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}
        [ ! -d ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes ] && mkdir -p ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes

        exit 0
        """
}

process get_footprint_file {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val evaluation_files

    output:
        stdout emit: stdout

    script:
        """
        python3 /app/get_footprint_files.py -f $evaluation_files
        """
}

process generate_tile_map {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val footprint_file
        val extract_check

    output:
        stdout emit: obs_id
        val pixel_map_csv, emit: pixel_map_csv

    script:
        pixel_map_csv = file("${params.WORKDIR}/${params.SBID}/*.csv").first()

        """
        python3 /app/generate_tile_pixel_map.py \
            -f "${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR}/$footprint_file" \
            -o "${params.WORKDIR}/${params.SBID}" \
            -j "${params.HPX_TILE_CONFIG}"
        """
}

process split_cube {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val stokes

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/split_cube.py \
            -i "$image_cube" \
            -o "${params.WORKDIR}/${params.SBID}/${params.SPLIT_CUBE_SUBDIR}" \
            -n ${params.NSPLIT}
        """
}

process get_split_cubes {
    executor = "local"

    input:
        val check

    output:
        val subcubes, emit: subcubes

    exec:
        subcubes = file("${params.WORKDIR}/${params.SBID}/${params.SPLIT_CUBE_SUBDIR}/*.fits")
}

process run_hpx_tiling {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val obs_id
        val image_cube
        val pixel_map_csv
        val stokes

    output:
        stdout emit: stdout

    script:
        prefix = image_cube.getBaseName()

        """
        python3 -u /app/casa_tiling.py \
            -i "$obs_id" \
            -c "$image_cube" \
            -m "$pixel_map_csv" \
            -o "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes" \
            -t "${params.HPX_TILE_TEMPLATE}" \
            -p "$prefix"
        """
}

process get_tiles {
    executor = 'local'

    input:
        val check
        val stokes

    output:
        val files, emit: files

    exec:
        files = file("${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes/*.fits")
        """
        #!/bin/bash
        echo $check
        """
}

process get_unique_pixel_ids {
    executor = 'local'

    input:
        val check
        val obs_id
        val stokes

    output:
        val pixel_id, emit: pixel_id

    exec:
        pixel_id = file("${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes/$obs_id/*.fits")
            .collect{ path -> path.baseName.split('-')[-1] }
            .unique()
}

process get_split_hpx_pixels {
    executor = 'local'

    input:
        val pixel_id
        val obs_id
        val stokes

    output:
        val files, emit: files
        val pixel_id, emit: pixel_id

    exec:
       files = file("${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes/$obs_id/*$pixel_id*.fits")
}

process join_split_hpx_tiles {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val files
        val pixel_id
        val obs_id
        val stokes

    output:
        val hpx_tile, emit: hpx_tile

    script:
        file_string = files.join(' ')
        hpx_tile = file("${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes/$obs_id/PoSSUM_${stokes}_${pixel_id}.fits")

        """
        python3 -u /app/join_subcubes.py \
            -f $file_string \
            -o $hpx_tile \
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
        stokes
        pixel_map

    main:
        split_cube(image_cube, "i")
        get_split_cubes(split_cube.out.stdout)
        run_hpx_tiling(
            obs_id,
            get_split_cubes.out.subcubes.flatten(),
            pixel_map,
            stokes
        )
        get_unique_pixel_ids(run_hpx_tiling.out.stdout.collect(), obs_id, stokes)
        get_split_hpx_pixels(get_unique_pixel_ids.out.pixel_id.flatten(), obs_id, stokes)
        join_split_hpx_tiles(get_split_hpx_pixels.out.files, get_split_hpx_pixels.out.pixel_id, obs_id, stokes)

    emit:
        tiles = join_split_hpx_tiles.out.hpx_tile.collect()
}

workflow split_tiling {
    take:
        sbid
        image_cube
        stokes
        evaluation_files
        metadata_dir

    main:
        check(sbid, image_cube, stokes)
        get_footprint_file(evaluation_files)
        generate_tile_map(get_footprint_file.out.stdout, metadata_dir)
        split_casa_tiling(generate_tile_map.out.obs_id, image_cube, stokes, generate_tile_map.out.pixel_map_csv)

    emit:
        obs_id = generate_tile_map.out.obs_id
        tiles = split_casa_tiling.out.tiles
}

workflow tiling {
    take:
        sbid
        image_cube
        stokes
        evaluation_files
        metadata_dir

    main:
        check(sbid, image_cube, stokes)
        get_footprint_file(evaluation_files)
        generate_tile_map(get_footprint_file.out.stdout, metadata_dir)
        run_hpx_tiling(generate_tile_map.out.obs_id, image_cube, stokes, generate_tile_map.out.pixel_map_csv)
        get_tiles(run_hpx_tiling.out.stdout, stokes)

    emit:
        obs_id = generate_tile_map.out.obs_id
        tiles = get_tiles.out.tiles
}

// ----------------------------------------------------------------------------------------

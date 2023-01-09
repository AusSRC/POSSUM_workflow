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
        val tile_map

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check important files
        [ ! -f $image_cube ] && { echo "Image cube file does not exist"; exit 1; }
        [ ! -f $tile_map ] && { echo "HPX tile map file does not exist"; exit 1; }
        [ ! -f ${params.HPX_TILE_CONFIG} ] && { echo "HEALPIX tiling configuration file does not exist"; exit 1; }

        # Check working directories
        [ ! -d ${params.WORKDIR}/$sbid ] && mkdir -p ${params.WORKDIR}/$sbid
        [ ! -d ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR} ] && mkdir -p ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}
        [ ! -d ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes ] && mkdir -p ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes

        exit 0
        """
}

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
        export CASADATA=${params.CASADATA}/casadata
        export PYTHONPATH='\$PYTHONPATH:${params.CASADATA}'

        python3 -u /app/split_cube.py \
            -i "$image_cube" \
            -o "${params.WORKDIR}/${params.SBID}/${params.SPLIT_CUBE_SUBDIR}" \
            -n ${params.NSPLIT}
        """
}

process get_split_cubes {
    executor = "local"

    input:
        val files_str

    output:
        val subcubes, emit: subcubes

    exec:
        filenames = files_str.split(',')
        subcubes = filenames.collect{ it = file("${params.WORKDIR}/${params.SBID}/${params.SPLIT_CUBE_SUBDIR}/$it") }
}

// This is required for the beamcon "robust" method.
process nan_to_zero {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube

    output:
        val image_cube_zeros, emit: image_cube_zeros

    script:
        filename = file(image_cube)
        image_cube_zeros = "${filename.getParent()}/${filename.getBaseName()}.zeros.${filename.getExtension()}"

        """
        #!python3

        import numpy as np
        from astropy.io import fits

        with fits.open("$image_cube", mode="readonly") as hdu:
            header = hdu[0].header
            data = np.nan_to_num(hdu[0].data)
            header['HISTORY'] = 'Replace NaN with zero'
        hdu = fits.PrimaryHDU(data=data, header=header)
        hdul = fits.HDUList([hdu])
        hdul.writeto("$image_cube_zeros", overwrite=True)
        """
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
        prefix = file(image_cube).getBaseName()

        """
        export CASADATA=${params.CASADATA}/casadata
        export PYTHONPATH='\$PYTHONPATH:${params.CASADATA}'

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

    script:
        files = file("${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes/$obs_id/*${obs_id}-${pixel_id}*.fits")
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
        pixel_map
        stokes

    main:
        split_cube(image_cube, stokes)
        get_split_cubes(split_cube.out.files_str)
        nan_to_zero(get_split_cubes.out.subcubes.flatten())
        run_hpx_tiling(
            obs_id,
            nan_to_zero.out.image_cube_zeros,
            pixel_map,
            stokes
        )
        get_unique_pixel_ids(run_hpx_tiling.out.stdout.collect(), obs_id, stokes)
        join_split_hpx_tiles(get_unique_pixel_ids.out.pixel_id.flatten(), obs_id, stokes)

    emit:
        tiles = join_split_hpx_tiles.out.hpx_tile.collect()
}

workflow split_tiling {
    take:
        sbid
        obs_id
        image_cube
        tile_map
        stokes

    main:
        check(sbid, image_cube, stokes, tile_map)
        split_casa_tiling(obs_id, image_cube, tile_map, stokes)

    emit:
        tiles = split_casa_tiling.out.tiles
}

workflow tiling {
    take:
        sbid
        obs_id
        image_cube
        tile_map
        stokes

    main:
        check(sbid, image_cube, stokes, tile_map)
        run_hpx_tiling(obs_id, image_cube, tile_map, stokes)
        get_tiles(run_hpx_tiling.out.stdout, stokes)

    emit:
        tiles = get_tiles.out.tiles
}

// ----------------------------------------------------------------------------------------

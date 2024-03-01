#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process process_pixel_map {
    executor = 'local'

    input:
        val pixel

    output:
        val pixel_stokes_list, emit: pixel_stokes_list_out

    exec:
        pixel_stokes_list = pixel.getValue()
}


process generate_linmos_config {

    executor = 'local'
    container = params.CASDA_DOWNLOAD_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val pixel_stokes

    output:
        val linmos_conf, emit: linmos_conf_out
        val linmos_log_conf, emit: linmos_log_conf_out
        val mosaic_files, emit: mosaic_files_out

    script:
        def v = pixel_stokes.getValue()
        def input_files = v.get('input')
        def output_files = v.get('output')
        def stokes = v.get('stokes')
        def pixel = v.get('pixel')
        def band = v.get('band')

        linmos_conf = "${params.WORKDIR}/tile_processing/" + pixel + "/linmos_" + band + "_" + stokes + ".conf"
        linmos_log_conf = "${params.WORKDIR}/tile_processing/" + pixel + "/linmos_" + band + "_" + stokes + ".log_cfg"
        mosaic_files = output_files

        """
        #!python3

        import os
        import json
        from jinja2 import Environment, FileSystemLoader
        from pathlib import Path

        img = [${input_files[0].collect{"\"${it}\""}.join(",")}]
        wgt = [${input_files[1].collect{"\"${it}\""}.join(",")}]

        images = [Path(image) for image in img]
        weights = [Path(weight) for weight in wgt]
        images.sort()
        weights.sort()

        image_out = Path('${output_files[0]}')
        weight_out = Path('${output_files[1]}')
        log = Path('${linmos_log_conf}.txt')

        j2_env = Environment(loader=FileSystemLoader('$baseDir/templates'), trim_blocks=True)
        result = j2_env.get_template('linmos.j2').render(images=images, weights=weights, \
        image_out=image_out, weight_out=weight_out)

        try:
            os.makedirs(os.path.dirname('${linmos_conf}'))
        except:
            pass

        try:
            os.makedirs(os.path.dirname('${linmos_log_conf}'))
        except:
            pass

        try:
            os.makedirs(os.path.dirname('${output_files[0]}'))
        except:
            pass

        try:
            os.makedirs(os.path.dirname('${output_files[1]}'))
        except:
            pass

        with open('${linmos_conf}', 'w') as f:
            print(result, file=f)

        result = j2_env.get_template('log_template.j2').render(log=log)

        with open('${linmos_log_conf}', 'w') as f:
            print(result, file=f)
        """
}


process run_linmos {

    input:
        val linmos_conf
        val linmos_log_conf
        val mosaic_files

    output:
        val mosaic_files, emit: mosaic_files

    script:
        def image_file = mosaic_files[0]
        """
        #!/bin/bash

        if ! test -f $image_file; then
            srun -n 6 singularity exec \
                --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
                ${params.SINGULARITY_CACHEDIR}/${params.LINMOS_IMAGE_NAME}.img \
                linmos-mpi -c $linmos_conf -l $linmos_log_conf
        fi
        """
}



// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow mosaicking {
    take:
        pixel_map

    main:
        process_pixel_map(pixel_map.flatMap())

        generate_linmos_config(process_pixel_map.out.pixel_stokes_list_out.flatMap())

        run_linmos(generate_linmos_config.out.linmos_conf_out,
                   generate_linmos_config.out.linmos_log_conf_out,
                   generate_linmos_config.out.mosaic_files_out)

    emit:
        mosaic_files = run_linmos.out.mosaic_files
}

// ----------------------------------------------------------------------------------------
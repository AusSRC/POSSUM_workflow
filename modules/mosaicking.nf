#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process generate_linmos_config {
    executor = 'local'
    container = params.CASDA_DOWNLOAD_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    /* Expects input object "pixel_stokes_config" with the following format
        i = {
            pixel=11400,
            band=1,
            stokes=i,
            input=[
                [PSM.0954-55.11400.i, PSM.1017-60.11400.i, PSM.1029-55.11400.i, PSM.1058-60.11400.i],
                [PSM.0954-55.11400.w, PSM.1017-60.11400.w, PSM.1029-55.11400.w, PSM.1058-60.11400.w]],
            output=[POSSUM.band1.1017-60_1029-55_0954-55_1058-60.11400.i, POSSUM.band1.1017-60_1029-55_0954-55_1058-60.11400.w]
        }
    */

    input:
        val pixel_stokes_config
        val survey_component

    output:
        val linmos_conf, emit: linmos_conf_out
        val linmos_log_conf, emit: linmos_log_conf_out
        val input_files, emit: mosaic_files_in
        val output_files, emit: mosaic_files_out

    script:
        def v = pixel_stokes_config.getValue()
        def stokes = v.get('stokes')
        def pixel = v.get('pixel')
        def band = v.get('band')

        input_files = v.get('input')
        output_files = v.get('output')
        linmos_conf = "${params.WORKDIR}/tile_processing/" + pixel + "/linmos_" + survey_component + "_" + band + "_" + stokes + ".conf"
        linmos_log_conf = "${params.WORKDIR}/tile_processing/" + pixel + "/linmos_" + survey_component + "_" + band + "_" + stokes + ".log_cfg"

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

        stokes = str('${stokes}')
        if stokes != 'i':
            weight_out = ''

        image_history = [
            "AusSRC POSSUM pipeline tile mosaicking START",
            "${workflow.repository} - ${workflow.revision} [${workflow.commitId}]",
            "${workflow.commandLine}",
            "${workflow.start}",
            "Austin Shen (austin.shen@csiro.au)",
            "AusSRC POSSUM pipeline tile mosaicking END"
        ]

        j2_env = Environment(loader=FileSystemLoader('$baseDir/templates'), trim_blocks=True)
        result = j2_env.get_template('linmos.j2').render( \
            images=images, weights=weights, \
            image_out=image_out, weight_out=weight_out, image_history=image_history \
        )

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

/*
Script for flipping frequency and polarisation axes on data cubes. This code snippet is required
for linmos mosaicking POSSUM components since the desired axis order for their tiles is [ra, dec, freq, stokes].
Completed (mosaicked) tiles need to have their axes order flipped back to [ra, dec, freq, stokes] when complete.
*/

process flip_to_pol_freq {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image

    output:
        val true, emit: done
        val image, emit: image_cor

    script:
        """
        #!python3

        import os
        import numpy as np
        from astropy.io import fits

        filename = '$image'
        if not os.path.exists(filename):
            filename = '${image}.fits'
        assert os.path.exists(filename), 'Input image file not found'

        header_options = ['CTYPE', 'CRVAL', 'CDELT', 'CRPIX', 'CUNIT']
        with fits.open(filename, mode='update') as hdul:
            hdr = hdul[0].header
            if (hdr['NAXIS'] != 4) or (hdr['CTYPE3'] == 'STOKES' and hdr['CTYPE4'] == 'FREQ'):
                exit(0)
            data_flipped = np.swapaxes(hdul[0].data, 1, 0)
            for option in header_options:
                hdr[f'{option}3'], hdr[f'{option}4'] = hdr[f'{option}4'], hdr[f'{option}3']
            hdul[0].header = hdr
            hdul[0].data = data_flipped
            hdul.flush()
        """
}

process flip_to_freq_pol {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image

    output:
        val true, emit: done
        val image, emit: image_cor

    script:
        """
        #!python3

        import os
        import numpy as np
        from astropy.io import fits

        filename = '$image'
        if not os.path.exists(filename):
            filename = '${image}.fits'
        assert os.path.exists(filename), 'Input image file not found'

        header_options = ['CTYPE', 'CRVAL', 'CDELT', 'CRPIX', 'CUNIT']
        with fits.open(filename, mode='update') as hdul:
            hdr = hdul[0].header
            if (hdr['NAXIS'] != 4) or (hdr['CTYPE3'] == 'FREQ' and hdr['CTYPE4'] == 'STOKES'):
                exit(0)
            data_flipped = np.swapaxes(hdul[0].data, 1, 0)
            for option in header_options:
                hdr[f'{option}3'], hdr[f'{option}4'] = hdr[f'{option}4'], hdr[f'{option}3']
            hdul[0].header = hdr
            hdul[0].data = data_flipped
            hdul.flush()
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

        export OMP_NUM_THREADS=4
        if ! test -f $image_file; then
            singularity exec \
                --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
                ${params.SINGULARITY_CACHEDIR}/${params.LINMOS_IMAGE_NAME}.img \
                linmos -c $linmos_conf -l $linmos_log_conf
        fi
        """
}

process run_linmos_mpi {
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

        export OMP_NUM_THREADS=4
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
        pixel_stokes_config
        survey_component

    main:
        generate_linmos_config(pixel_stokes_config, survey_component)

        if (survey_component == 'mfs') {
            run_linmos(
                generate_linmos_config.out.linmos_conf_out,
                generate_linmos_config.out.linmos_log_conf_out,
                generate_linmos_config.out.mosaic_files_out,
            )
            mosaic_files = run_linmos.out.mosaic_files
        }

        // Flip axes to [ra, dec, pol, freq] for linmos MPI
        else {
            generate_linmos_config.out.mosaic_files_in.view()
            run_linmos_mpi(
                generate_linmos_config.out.linmos_conf_out,
                generate_linmos_config.out.linmos_log_conf_out,
                generate_linmos_config.out.mosaic_files_out
            )
            run_linmos_mpi.out.mosaic_files.flatten().view()
            flip_to_freq_pol(run_linmos_mpi.out.mosaic_files.flatten().unique())
            mosaic_files = flip_to_freq_pol.out.image_cor.collect()
        }

    emit:
        mosaic_files
}

// ----------------------------------------------------------------------------------------
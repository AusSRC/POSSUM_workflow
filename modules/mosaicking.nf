#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { linmos_config; linmos; linmos_mpi } from '../pipeline_components/nextflow/modules/linmos'

// ----------------------------------------------------------------------------------------
// Functions
// ----------------------------------------------------------------------------------------

// Describe the mosaic of one Stokes parameter of a HEALPix pixel (tile) as a job for the
// linmos module in pipeline_components. The pixel_stokes_config has the format
//      {
//          pixel=11400,
//          band=1,
//          stokes=i,
//          input=[
//              [PSM.0954-55.11400.i, PSM.1017-60.11400.i, PSM.1029-55.11400.i, PSM.1058-60.11400.i],
//              [PSM.0954-55.11400.w, PSM.1017-60.11400.w, PSM.1029-55.11400.w, PSM.1058-60.11400.w]],
//          output=[POSSUM.band1.1017-60_1029-55_0954-55_1058-60.11400.i, POSSUM.band1.1017-60_1029-55_0954-55_1058-60.11400.w]
//      }
// The weights are only written for the Stokes I mosaic, since they are the same for Q and U.
def possum_job(pixel_stokes_config, survey_component) {
    def pixel = pixel_stokes_config.pixel
    def band = pixel_stokes_config.band
    def stokes = pixel_stokes_config.stokes
    def (images, weights) = pixel_stokes_config.input
    def (image_out, weights_out) = pixel_stokes_config.output

    return [
        name: "${pixel}.${stokes}",
        images: images.sort(),
        weights: weights.sort(),
        image_out: image_out,
        weights_out: stokes == 'i' ? weights_out : '',
        config: "${params.WORKDIR}/tile_processing/${pixel}/linmos_${survey_component}_${band}_${stokes}.conf",
        history: [
            "AusSRC POSSUM pipeline tile mosaicking START",
            "${workflow.repository} - ${workflow.revision} [${workflow.commitId}]",
            "${workflow.commandLine}",
            "${workflow.start}",
            "Austin Shen (austin.shen@csiro.au)",
            "AusSRC POSSUM pipeline tile mosaicking END"
        ]
    ]
}

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

/*
Script for flipping frequency and polarisation axes on data cubes. This code snippet is required
for linmos mosaicking POSSUM components since the desired axis order for their tiles is [ra, dec, freq, stokes].
Completed (mosaicked) tiles need to have their axes order flipped back to [ra, dec, freq, stokes] when complete.
*/

process flip_to_pol_freq {
    errorStrategy { sleep(10); return 'retry' }
    maxRetries 3

    container = params.AUSSRC_PIPELINE_COMPONENTS_IMAGE
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
    container = params.AUSSRC_PIPELINE_COMPONENTS_IMAGE
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

/*
Linmos requires fits header cards CRPIX, CRVAL, CDELT to be floats. This process converts to float where
it has been stored as a string.
*/

process fix_string_header {
    container = params.AUSSRC_PIPELINE_COMPONENTS_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube

    output:
        val true, emit: done
        val image_cube, emit: image_cube_cor

    script:
        """
        #!python3
        import os
        from astropy.io import fits
        headers = ['CRPIX', 'CRVAL', 'CDELT']
        filename = '${image_cube}.fits'
        assert os.path.exists(filename), 'File does not exist'
        with fits.open(filename, mode='update') as hdul:
            header = hdul[0].header
            naxis = header['NAXIS']
            for i in range(naxis):
                for prefix in headers:
                    card = '%s%i' % (prefix, i+1)
                    header[card] = float(header[card])
            hdul.flush()
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
        // One linmos job for each Stokes parameter of the pixel
        jobs = pixel_stokes_config.map { stokes_config -> possum_job(stokes_config.getValue(), survey_component) }
        linmos_config(jobs)

        // Fix the headers of every input cube once (the weights are shared by the Stokes parameters)
        fix_string_header(jobs.flatMap { job -> job.images + job.weights }.unique())

        // Expect [ra, dec, freq, pol] order in MFS
        if (survey_component == 'mfs') {
            flip_to_pol_freq(fix_string_header.out.image_cube_cor)

            // Run linmos once all of the input cubes are ready
            inputs_ready = flip_to_pol_freq.out.done.collect().map { true }
            linmos(linmos_config.out.job.combine(inputs_ready).map { job, ready -> job })
            mosaic_files = linmos.out.mosaic
        }

        // Flip axes to [ra, dec, pol, freq] for linmos MPI
        else {
            // Run linmos once all of the input cubes are ready
            inputs_ready = fix_string_header.out.done.collect().map { true }
            linmos_mpi(linmos_config.out.job.combine(inputs_ready).map { job, ready -> job })
            flip_to_freq_pol(linmos_mpi.out.mosaic.flatten().unique())
            mosaic_files = flip_to_freq_pol.out.image_cor.collect()
        }

    emit:
        mosaic_files
}

// ----------------------------------------------------------------------------------------

#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Generate configuration
process generate_config {
    container = params.WALLABY_COMPONENTS_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val cubes

    output:
        stdout emit: linmos_config

    script:
        """
        python3 -u /app/generate_linmos_config.py \
            -i "$cubes" \
            -f ${params.WORKDIR}/${params.LINMOS_OUTPUT_IMAGE_CUBE} \
            -c ${params.WORKDIR}/${params.LINMOS_CONFIG_FILENAME}
        """
}

// Linear mosaicking
process linmos {
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"
    clusterOptions = params.LINMOS_CLUSTER_OPTIONS

    input:
        val linmos_config
    
    output:
        val "${params.WORKDIR}/${params.LINMOS_OUTPUT_IMAGE_CUBE}.fits", emit: mosaicked_cube

    script:
        """
        #!/bin/bash

        singularity pull ${params.SINGULARITY_CACHEDIR}/csirocass_yandasoft.img ${params.LINMOS_IMAGE}
        mpirun --mca btl_tcp_if_exclude docker0,lo \
            singularity exec ${params.SINGULARITY_CACHEDIR}/csirocass_yandasoft.img \
            linmos-mpi -c $linmos_config
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow mosaicking {
    take: cubes

    main:
        generate_config(cubes.collect())
        linmos(generate_config.out.linmos_config)
    
    emit:
        cube = linmos.out.mosaicked_cube
}

// ----------------------------------------------------------------------------------------


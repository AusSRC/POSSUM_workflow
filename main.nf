#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { mosaicking } from './mosaicking/main'
include { ionospheric_correction } from './ionospheric_correction/main'

workflow {
    q_cubes = Channel.of(params.Q_CUBES.split(','))
    u_cubes = Channel.of(params.U_CUBES.split(','))
    i_cubes = Channel.of(params.I_CUBES.split(','))
    weight_cubes = Channel.of(params.WEIGHT_CUBES.split(','))

    main: 
        ionospheric_correction(q_cubes, u_cubes)
        // mosaicking(ionospheric_correction.q_cubes_output.flatten(), weight_cubes.flatten())
        // mosaicking(ionospheric_correction.u_cubes_output.flatten(), weight_cubes.flatten())
        // mosaicking(i_cubes.flatten(), weight_cubes.flatten())
}
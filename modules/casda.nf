#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { download; download_evaluation_files } from '../pipeline_components/nextflow/modules/casda'

// CASDA TAP queries for the POSSUM (spectral cubes) and EMU (MFS images) data products
def possum_query(sbid) {
    return "SELECT * FROM ivoa.obscore WHERE obs_id IN ('${sbid}') AND " +
           "dataproduct_type='cube' AND (" +
           "filename LIKE 'image.restored.i.%.contcube.conv.fits' OR " +
           "filename LIKE 'weights.q.%.contcube.fits' OR " +
           "filename LIKE 'image.restored.q.%.contcube.conv.fits' OR " +
           "filename LIKE 'image.restored.u.%.contcube.conv.fits')"
}

def emu_query(sbid) {
    return "SELECT * FROM ivoa.obscore WHERE obs_id IN ('${sbid}') AND (" +
           "filename LIKE 'image.i.%.cont.taylor.%.restored.conv.fits' OR " +
           "filename LIKE 'weights.i.%.cont.taylor%.fits')"
}

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

import groovy.json.JsonSlurper
process parse_possum_manifest {
    input:
        val manifest

    output:
        val i_file, emit: i_file
        val q_file, emit: q_file
        val u_file, emit: u_file
        val weights_file, emit: weights_file

    exec:
        i_file = null
        q_file = null
        u_file = null
        weights_file = null

        def inputFile = new File("$manifest")
        def InputJSON = new JsonSlurper().parseText(inputFile.text)
        InputJSON.each {
            if (it.contains('image.restored.i.')) {
                i_file = it
            }
            else if (it.contains('image.restored.q.')) {
                q_file = it
            }
            else if (it.contains('image.restored.u.')) {
                u_file = it
            }
            else if (it.contains('weights.')) {
                weights_file = it
            }
        }

        if (i_file == null) {
            throw new Exception("stokes i file is not found")
        }

        if (q_file == null) {
            throw new Exception("stokes q file is not found")
        }

        if (u_file == null) {
            throw new Exception("stokes u file is not found")
        }

        if (weights_file == null) {
            throw new Exception("weights file is not found")
        }
}

process parse_emu_manifest {
    input:
        val manifest

    output:
        val i_file, emit: i_file
        val weights_file, emit: weights_file

    exec:
        i_file = null
        weights_file = null

        def inputFile = new File("$manifest")
        def InputJSON = new JsonSlurper().parseText(inputFile.text)
        InputJSON.each {
            if (it.matches('(.*)image.i.(.*).cont.taylor.0.restored.conv.fits')) {
                i_file = it
            }
            else if (it.matches('(.*)weights.i.(.*).cont.taylor.0.(.*)')) {
                weights_file = it
            }
        }

        if (i_file == null) {
            throw new Exception("stokes i file is not found")
        }

        if (weights_file == null) {
            throw new Exception("weights file is not found")
        }
}

// ----------------------------------------------------------------------------------------
// Workflows
// ----------------------------------------------------------------------------------------

// Evaluation files for an observation from the POSSUM and EMU project codes. Downloaded to
//      <WORKDIR>/sbid_processing/<sbid>/<EVALUATION_FILES_DIR>
workflow evaluation_files {
    take:
        sbid

    main:
        download_evaluation_files(
            sbid,
            ['AS203', 'AS202', 'AS201'],
            "${params.WORKDIR}/sbid_processing/${sbid}/${params.EVALUATION_FILES_DIR}"
        )

    emit:
        evaluation_files = download_evaluation_files.out.evaluation_files
}

// Stokes I, Q, U cubes and weights cube for an observation. Downloaded to
//      <WORKDIR>/sbid_processing/<sbid>
workflow download_possum {
    take:
        sbid

    main:
        download(
            possum_query(sbid),
            "${params.WORKDIR}/sbid_processing/${sbid}",
            "${params.WORKDIR}/sbid_processing/${sbid}/${sbid}.json"
        )
        parse_possum_manifest(download.out.manifest)

    emit:
        i_file = parse_possum_manifest.out.i_file
        q_file = parse_possum_manifest.out.q_file
        u_file = parse_possum_manifest.out.u_file
        weights_file = parse_possum_manifest.out.weights_file
}

// EMU MFS image and weights for an observation. Downloaded to
//      <WORKDIR>/sbid_processing/<sbid>
workflow download_emu {
    take:
        sbid

    main:
        download(
            emu_query(sbid),
            "${params.WORKDIR}/sbid_processing/${sbid}",
            "${params.WORKDIR}/sbid_processing/${sbid}/mfs/${sbid}.json"
        )
        parse_emu_manifest(download.out.manifest)

    emit:
        i_file = parse_emu_manifest.out.i_file
        weights_file = parse_emu_manifest.out.weights_file
}

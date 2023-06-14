#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process find_complete {
    executor = 'local'

    input:
        val tileMap
        val stokes
        val mfs

    output:
        val tileIds, emit: tileIds
        val tileHPXFileMap, emit: tileHPXFileMap

    exec:
        tileIds = []
        tileObsIdMap = [:]
        tileHPXFileMap = [:]
        csvBody = tileMap.readLines()*.split(',')
        csvBody.remove(0)  // remove header
        csvBody.each{ tileObsIdMap[it[0]] = it[1..-1] }

        for (item in tileObsIdMap) {
            tileId = item.key
            files = []
            weights = []

            for (obsId in item.value) {
                if (mfs) {
                    search_stokes = "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes/$obsId/hpx/image.i.*$tileId*"
                }
                else {
                    search_stokes = "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes/$obsId/hpx/*$tileId*"
                }

                match = file(search_stokes)
                //System.out.println(match)

                if (match.size() == 0) {
                    println "No Match: " + obsId + " " + tileId
                    continue
                }
                // Add to map if file exists and there is only one
                else if (match.size() == 1) {
                    files.add(match.first())
                
                    if (mfs) {
                        search_weights = "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/w/$obsId/weights.i.*$tileId*"
                    }
                    else {
                        search_weights = "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/w/$obsId/hpx/*$tileId*"
                    }

                    match_weights = file(search_weights)
                    //System.out.println(search_weights)
                    if (match_weights.size() == 1) {
                        weights.add(match_weights.first())
                    }
                    else if (match_weights.size() == 0) {
                        throw new Exception("No weight can be found for $tileId")
                    }
                    else if (match_weights.size() > 1) {
                        throw new Exception("More than one wight file found for HPX tile id $tileId")
                    }

                }
                else if (match.size() > 1) {
                    throw new Exception("More than one file found for HPX tile id $tileId")
                }

            }

            // Completed tiles (all components available) only
            if (files.size() > 0) {
                tileIds.add(tileId)
                tileHPXFileMap[tileId] = [files, weights]
            }
        }

        if (tileIds.size() == 0) {
            println "ERROR: No HPX tiles have all constituent components. Exiting nicely :)"
        }
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow get_complete_tiles {
    take:
        tileMap
        stokes
        mfs

    main:
        find_complete(tileMap, stokes, mfs)

    emit:
        tile_ids = find_complete.out.tileIds
        id_to_files = find_complete.out.tileHPXFileMap
}

// ----------------------------------------------------------------------------------------

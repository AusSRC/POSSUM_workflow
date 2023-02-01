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
            for (obsId in item.value) {
                search = "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes/$obsId/*$tileId*"
                matchFile = file(search)

                // Add to map if file exists and there is only one
                if (matchFile.size() == 1) {
                    files.add(matchFile.first())
                }
                if (matchFile.size() > 1) {
                    throw new Exception("More than one file found for HPX tile id $tileId")
                }
            }

            // Completed tiles (all components available) only
            if (files.size() == item.value.size()) {
                tileIds.add(tileId)
                tileHPXFileMap[tileId] = files
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

    main:
        find_complete(tileMap, stokes)

    emit:
        tile_ids = find_complete.out.tileIds
        id_to_files = find_complete.out.tileHPXFileMap
}

// ----------------------------------------------------------------------------------------

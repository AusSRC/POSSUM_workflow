process objectstore_upload {

    input:
        val ready
        val obs_id
        val subdir
        
    script:
        """
        rclone --s3-chunk-size=128M --progress copy --ignore-checksum "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/${obs_id}/${subdir}" "ja3:aussrc/possum/components/${obs_id}/${subdir}"
        """
}
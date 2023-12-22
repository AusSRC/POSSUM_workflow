process objectstore_upload {

    input:
        val ready
        val obs_id
        val subdir
        
    script:
        """
        rclone --s3-chunk-size=128M --progress copy -u --ignore-checksum "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/${obs_id}/${subdir}" "pawsey0980:possum/components/${obs_id}/${subdir}"
        """
}
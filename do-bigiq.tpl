{
    "class": "DO",
    "declaration": {
        "schemaVersion": "1.5.0",
        "class": "Device",
        "async": true,
        "Common": {
            "class": "Tenant",
            "myProvision": {
                "class": "Provision",
                "ltm": "nominal",
                "asm": "nominal"
            },
            "myNtp": {
                "class": "NTP",
                "servers": [
                    "pool.ntp.org"
                ],
                "timezone": "Europe/Amsterdam"
            },
            "${user_name}": {
                "class": "User",
                "userType": "regular",
                "partitionAccess": {
                    "all-partitions": {
                        "role": "${user_name}"
                    }
                },
                "shell": "tmsh",
                "password": "${user_password}"
            }
        }
    },
    "targetHost": "${targethost}",
    "targetPort": 8443,
    "targetUsername": "admin",
    "targetSshKey": {
        "path": "/var/ssh/restnoded/${targetsshkey}"
    },
    "bigIqSettings": {
        "failImportOnConflict": false,
        "conflictPolicy": "USE_BIGIQ",
        "deviceConflictPolicy": "USE_BIGIP",
        "versionedConflictPolicy": "KEEP_VERSION",
        "statsConfig": {
            "enabled": true,
            "zone": "default"
        },
        "snapshotWorkingConfig": false
    }
}
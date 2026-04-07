package truckercore.iam

deny["SCIM discovery missing"] { not input.scim.discovery_ok }
deny["/Bulk must return 501"]  { not input.scim.bulk_501 }
deny["sortBy must be 400"]     { not input.scim.sort_400 }



# AlertEvent


## Properties

| Name | Type | Description | Notes |
|------------ | ------------- | ------------- | -------------|
|**id** | **UUID** |  |  [optional] |
|**severity** | [**SeverityEnum**](#SeverityEnum) |  |  [optional] |
|**code** | [**CodeEnum**](#CodeEnum) |  |  [optional] |
|**payload** | **Object** |  |  [optional] |
|**triggeredAt** | **OffsetDateTime** |  |  [optional] |
|**acknowledged** | **Boolean** |  |  [optional] |
|**acknowledgedBy** | **UUID** |  |  [optional] |
|**acknowledgedAt** | **OffsetDateTime** |  |  [optional] |



## Enum: SeverityEnum

| Name | Value |
|---- | -----|
| INFO | &quot;info&quot; |
| WARNING | &quot;warning&quot; |
| CRITICAL | &quot;critical&quot; |



## Enum: CodeEnum

| Name | Value |
|---- | -----|
| LATE_ETA | &quot;LATE_ETA&quot; |
| HOS_NEAR_LIMIT | &quot;HOS_NEAR_LIMIT&quot; |
| INSPECTION_WEEK | &quot;INSPECTION_WEEK&quot; |




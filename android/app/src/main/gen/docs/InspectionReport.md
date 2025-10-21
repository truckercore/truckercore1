

# InspectionReport


## Properties

| Name | Type | Description | Notes |
|------------ | ------------- | ------------- | -------------|
|**id** | **UUID** |  |  [optional] |
|**driverUserId** | **UUID** |  |  [optional] |
|**vehicleId** | **UUID** |  |  [optional] |
|**type** | [**TypeEnum**](#TypeEnum) |  |  [optional] |
|**defects** | [**List&lt;InspectionReportDefectsInner&gt;**](InspectionReportDefectsInner.md) |  |  [optional] |
|**certifiedSafe** | **Boolean** |  |  [optional] |
|**signedAt** | **OffsetDateTime** |  |  [optional] |
|**createdAt** | **OffsetDateTime** |  |  [optional] |



## Enum: TypeEnum

| Name | Value |
|---- | -----|
| PRE_TRIP | &quot;pre_trip&quot; |
| POST_TRIP | &quot;post_trip&quot; |






# ApiInspectionPostRequest


## Properties

| Name | Type | Description | Notes |
|------------ | ------------- | ------------- | -------------|
|**vehicleId** | **UUID** |  |  |
|**type** | [**TypeEnum**](#TypeEnum) |  |  |
|**defects** | [**List&lt;ApiInspectionPostRequestDefectsInner&gt;**](ApiInspectionPostRequestDefectsInner.md) |  |  |
|**certifiedSafe** | **Boolean** |  |  |
|**signedAt** | **OffsetDateTime** |  |  |



## Enum: TypeEnum

| Name | Value |
|---- | -----|
| PRE_TRIP | &quot;pre_trip&quot; |
| POST_TRIP | &quot;post_trip&quot; |




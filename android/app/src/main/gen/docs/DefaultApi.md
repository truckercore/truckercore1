# DefaultApi

All URIs are relative to *https://stage.yourdomain.com*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**apiAlertsGet**](DefaultApi.md#apiAlertsGet) | **GET** /api/alerts | List current alerts for org |
| [**apiAlertsIdAckPost**](DefaultApi.md#apiAlertsIdAckPost) | **POST** /api/alerts/{id}/ack | Acknowledge an alert |
| [**apiAnalyticsBrokerGet**](DefaultApi.md#apiAnalyticsBrokerGet) | **GET** /api/analytics/broker | Broker analytics KPIs and time series |
| [**apiAnalyticsExportCsvGet**](DefaultApi.md#apiAnalyticsExportCsvGet) | **GET** /api/analytics/export.csv | Export analytics as CSV |
| [**apiAnalyticsFleetGet**](DefaultApi.md#apiAnalyticsFleetGet) | **GET** /api/analytics/fleet | Fleet analytics KPIs and time series |
| [**apiHosDriverUserIdGet**](DefaultApi.md#apiHosDriverUserIdGet) | **GET** /api/hos/{driver_user_id} | Get HOS logs (7–30 days) |
| [**apiInspectionPost**](DefaultApi.md#apiInspectionPost) | **POST** /api/inspection | Submit pre/post trip inspection |
| [**apiOwneropExpensesPost**](DefaultApi.md#apiOwneropExpensesPost) | **POST** /api/ownerop/expenses | Create an expense |
| [**apiOwneropProfitGet**](DefaultApi.md#apiOwneropProfitGet) | **GET** /api/ownerop/profit | Owner-Operator profit summary |
| [**apiOwneropTaxExportCsvGet**](DefaultApi.md#apiOwneropTaxExportCsvGet) | **GET** /api/ownerop/tax/export.csv | Export quarterly CSV for taxes |


<a id="apiAlertsGet"></a>
# **apiAlertsGet**
> List&lt;AlertEvent&gt; apiAlertsGet(code)

List current alerts for org

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    String code = "LATE_ETA"; // String | 
    try {
      List<AlertEvent> result = apiInstance.apiAlertsGet(code);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiAlertsGet");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **code** | **String**|  | [optional] [enum: LATE_ETA, HOS_NEAR_LIMIT, INSPECTION_WEEK] |

### Return type

[**List&lt;AlertEvent&gt;**](AlertEvent.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | OK |  -  |
| **403** | Forbidden |  -  |

<a id="apiAlertsIdAckPost"></a>
# **apiAlertsIdAckPost**
> ApiAlertsIdAckPost200Response apiAlertsIdAckPost(id)

Acknowledge an alert

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    UUID id = UUID.randomUUID(); // UUID | 
    try {
      ApiAlertsIdAckPost200Response result = apiInstance.apiAlertsIdAckPost(id);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiAlertsIdAckPost");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **id** | **UUID**|  | |

### Return type

[**ApiAlertsIdAckPost200Response**](ApiAlertsIdAckPost200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | OK |  -  |
| **403** | Forbidden |  -  |
| **404** | Not found |  -  |

<a id="apiAnalyticsBrokerGet"></a>
# **apiAnalyticsBrokerGet**
> AnalyticsResponse apiAnalyticsBrokerGet(from, to)

Broker analytics KPIs and time series

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    LocalDate from = LocalDate.now(); // LocalDate | 
    LocalDate to = LocalDate.now(); // LocalDate | 
    try {
      AnalyticsResponse result = apiInstance.apiAnalyticsBrokerGet(from, to);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiAnalyticsBrokerGet");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **from** | **LocalDate**|  | |
| **to** | **LocalDate**|  | |

### Return type

[**AnalyticsResponse**](AnalyticsResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | OK |  -  |
| **400** | Bad request |  -  |
| **403** | Forbidden |  -  |

<a id="apiAnalyticsExportCsvGet"></a>
# **apiAnalyticsExportCsvGet**
> File apiAnalyticsExportCsvGet(scope, from, to)

Export analytics as CSV

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    String scope = "fleet"; // String | 
    LocalDate from = LocalDate.now(); // LocalDate | 
    LocalDate to = LocalDate.now(); // LocalDate | 
    try {
      File result = apiInstance.apiAnalyticsExportCsvGet(scope, from, to);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiAnalyticsExportCsvGet");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **scope** | **String**|  | [enum: fleet, broker] |
| **from** | **LocalDate**|  | |
| **to** | **LocalDate**|  | |

### Return type

[**File**](File.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/csv

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | CSV |  * Content-Type -  <br>  * Content-Disposition -  <br>  |
| **400** | Bad request |  -  |
| **403** | Forbidden |  -  |

<a id="apiAnalyticsFleetGet"></a>
# **apiAnalyticsFleetGet**
> AnalyticsResponse apiAnalyticsFleetGet(from, to)

Fleet analytics KPIs and time series

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    LocalDate from = LocalDate.now(); // LocalDate | 
    LocalDate to = LocalDate.now(); // LocalDate | 
    try {
      AnalyticsResponse result = apiInstance.apiAnalyticsFleetGet(from, to);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiAnalyticsFleetGet");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **from** | **LocalDate**|  | |
| **to** | **LocalDate**|  | |

### Return type

[**AnalyticsResponse**](AnalyticsResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | OK |  -  |
| **400** | Bad request |  -  |
| **403** | Forbidden |  -  |

<a id="apiHosDriverUserIdGet"></a>
# **apiHosDriverUserIdGet**
> ApiHosDriverUserIdGet200Response apiHosDriverUserIdGet(driverUserId, from, to)

Get HOS logs (7–30 days)

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    UUID driverUserId = UUID.randomUUID(); // UUID | 
    LocalDate from = LocalDate.now(); // LocalDate | 
    LocalDate to = LocalDate.now(); // LocalDate | 
    try {
      ApiHosDriverUserIdGet200Response result = apiInstance.apiHosDriverUserIdGet(driverUserId, from, to);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiHosDriverUserIdGet");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **driverUserId** | **UUID**|  | |
| **from** | **LocalDate**|  | [optional] |
| **to** | **LocalDate**|  | [optional] |

### Return type

[**ApiHosDriverUserIdGet200Response**](ApiHosDriverUserIdGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | OK |  -  |
| **400** | Bad request |  -  |
| **403** | Forbidden |  -  |
| **404** | Driver not found |  -  |

<a id="apiInspectionPost"></a>
# **apiInspectionPost**
> InspectionReport apiInspectionPost(apiInspectionPostRequest)

Submit pre/post trip inspection

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    ApiInspectionPostRequest apiInspectionPostRequest = new ApiInspectionPostRequest(); // ApiInspectionPostRequest | 
    try {
      InspectionReport result = apiInstance.apiInspectionPost(apiInspectionPostRequest);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiInspectionPost");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **apiInspectionPostRequest** | [**ApiInspectionPostRequest**](ApiInspectionPostRequest.md)|  | |

### Return type

[**InspectionReport**](InspectionReport.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | OK |  -  |
| **400** | Validation error |  -  |
| **403** | Forbidden |  -  |

<a id="apiOwneropExpensesPost"></a>
# **apiOwneropExpensesPost**
> OwnerOpExpense apiOwneropExpensesPost(apiOwneropExpensesPostRequest)

Create an expense

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    ApiOwneropExpensesPostRequest apiOwneropExpensesPostRequest = new ApiOwneropExpensesPostRequest(); // ApiOwneropExpensesPostRequest | 
    try {
      OwnerOpExpense result = apiInstance.apiOwneropExpensesPost(apiOwneropExpensesPostRequest);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiOwneropExpensesPost");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **apiOwneropExpensesPostRequest** | [**ApiOwneropExpensesPostRequest**](ApiOwneropExpensesPostRequest.md)|  | |

### Return type

[**OwnerOpExpense**](OwnerOpExpense.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Created |  -  |
| **400** | Validation error |  -  |
| **403** | Forbidden |  -  |

<a id="apiOwneropProfitGet"></a>
# **apiOwneropProfitGet**
> OwnerOpProfitResponse apiOwneropProfitGet(from, to)

Owner-Operator profit summary

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    LocalDate from = LocalDate.now(); // LocalDate | 
    LocalDate to = LocalDate.now(); // LocalDate | 
    try {
      OwnerOpProfitResponse result = apiInstance.apiOwneropProfitGet(from, to);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiOwneropProfitGet");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **from** | **LocalDate**|  | |
| **to** | **LocalDate**|  | |

### Return type

[**OwnerOpProfitResponse**](OwnerOpProfitResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | OK |  -  |
| **400** | Bad request |  -  |
| **403** | Forbidden |  -  |

<a id="apiOwneropTaxExportCsvGet"></a>
# **apiOwneropTaxExportCsvGet**
> File apiOwneropTaxExportCsvGet(quarter)

Export quarterly CSV for taxes

### Example
```java
// Import classes:
import org.openapitools.client.ApiClient;
import org.openapitools.client.ApiException;
import org.openapitools.client.Configuration;
import org.openapitools.client.auth.*;
import org.openapitools.client.models.*;
import org.openapitools.client.api.DefaultApi;

public class Example {
  public static void main(String[] args) {
    ApiClient defaultClient = Configuration.getDefaultApiClient();
    defaultClient.setBasePath("https://stage.yourdomain.com");
    
    // Configure HTTP bearer authorization: bearerAuth
    HttpBearerAuth bearerAuth = (HttpBearerAuth) defaultClient.getAuthentication("bearerAuth");
    bearerAuth.setBearerToken("BEARER TOKEN");

    DefaultApi apiInstance = new DefaultApi(defaultClient);
    String quarter = "Q3-2025"; // String | 
    try {
      File result = apiInstance.apiOwneropTaxExportCsvGet(quarter);
      System.out.println(result);
    } catch (ApiException e) {
      System.err.println("Exception when calling DefaultApi#apiOwneropTaxExportCsvGet");
      System.err.println("Status code: " + e.getCode());
      System.err.println("Reason: " + e.getResponseBody());
      System.err.println("Response headers: " + e.getResponseHeaders());
      e.printStackTrace();
    }
  }
}
```

### Parameters

| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **quarter** | **String**|  | |

### Return type

[**File**](File.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/csv

### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | CSV |  * Content-Type -  <br>  * Content-Disposition -  <br>  |
| **400** | Bad request |  -  |
| **403** | Forbidden |  -  |


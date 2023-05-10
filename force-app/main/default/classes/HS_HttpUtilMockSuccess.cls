@isTest
global class HS_HttpUtilMockSuccess implements HttpCalloutMock{
    global HttpResponse respond(HttpRequest req){
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type','application/json');
        res.setBody('{"Animals":["Horse","Dog","Tiger","Lion","Cat","Mouse"]}');
        res.setStatusCode(200);
        return res;
    }
}
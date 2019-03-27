var isAlreadyCollectedById = { <AlreadyDeliveredOfferData> }

window.Android = {
    getContentScheduleAsJsonString:
    function () {
        return <listingData>
    },
    
    getCouponDataAsJsonString:
    function () {
        return <couponData>
    },
    
    getBasicAuthorizationPassword:
    function () {
        return '<authToken>';
    },

    getSelectedCategoryTabBackgroundColor:
    function () {
        return '<tabBackgroundColor>';
    },

    openCouponUrl:
    function (url, offerScheduleId) {
        window.webkit.messageHandlers.openCoupon.postMessage(offerScheduleId);
    },

    blockOfferbyOfferScheduleId:
    function (offerScheduleId) {
        window.webkit.messageHandlers.deleteOffer.postMessage(offerScheduleId);
    },

    isOfferCollectedByScheduleId:
    function (scheduleId) {
        console.log("isOfferCollectedByScheduleId:" + scheduleId);
        return isAlreadyCollectedById[scheduleId];
    },
    
    getDeliveredToAppTimestampSecondsByScheduleIdAsJsonString:
    function () {
        return {<deliveredIdsAndTimestamps>}
    },
};


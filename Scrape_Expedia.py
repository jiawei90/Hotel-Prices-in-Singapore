from datetime import date
from datetime import timedelta

from lxml import html
from time import sleep
import calendar
from selenium import webdriver

from pymongo import MongoClient
import re
import datetime

# =============================================================================
# Constant
# =============================================================================
numberOfTab = 3
counter = 0
loop = 0
dbduplicate = 0
durationgap = 3

todayDate = date.today().strftime("%d/%m/%Y")
todayDateImport = datetime.datetime.utcnow()
checkindate = datetime.datetime(2018, 8, 31)
nextDay = timedelta(days=1)
duration = timedelta(days=durationgap)
endDate = datetime.datetime(2019, 9, 1)
searchKey = "Singapore, Singapore"

# =============================================================================
# Simple Function
# =============================================================================

def diff_dates(date1, date2):
    return abs(date2-date1).days

# =============================================================================
# Database
# =============================================================================
try:
    conn = MongoClient('54.169.201.91', 27017)
    print("Connected successfully!!!")
except:  
    print("Could not connect to MongoDB")

db = conn.ke5106

collection_price_detail = db.price_details
collection_hotel = db.hotel

# =============================================================================
# Start of Scraping    
# =============================================================================
while checkindate != endDate:
    checkindate = checkindate + nextDay    
    checkoutdate = checkindate + duration
    checkInDate1 = checkindate.strftime("%d/%m/%Y")
    checkOutDate1 = checkoutdate.strftime("%d/%m/%Y")
    checkInDate2 = checkindate.strftime("%m/%d/%Y")
    checkOutDate2 = checkoutdate.strftime("%m/%d/%Y")
    
    try:
        browserFirefox = webdriver.Firefox()
        browserFirefox.get('http://www.expedia.com')
        
        multi_screen_data_search = browserFirefox.find_element_by_xpath("//button[@id='tab-hotel-tab-hp']")
        multi_screen_data_search.click()
    
        searchKeyElement = browserFirefox.find_elements_by_xpath('//input[contains(@id,"hotel-destination-hp-hotel")]')
        checkInElement =browserFirefox.find_elements_by_xpath('//input[contains(@id,"hotel-checkin-hp-hotel")]')
        checkOutElement = browserFirefox.find_elements_by_xpath('//input[contains(@id,"hotel-checkout-hp-hotel")]')
     
        if searchKeyElement and checkInElement and checkOutElement:
            searchKeyElement[0].send_keys(searchKey)

            multi_screen_data_search.click()
            checkOutElement[0].clear()

            checkOutElement[0].send_keys(checkOutDate2)
            multi_screen_data_search.click()
            checkInElement[0].clear()     
            
            checkInElement[0].send_keys(checkInDate2)
            multi_screen_data_search.click()
         
            submitButton3 = browserFirefox.find_elements_by_xpath('//button[contains(@class,"btn-primary btn-action  gcw-submit")]')
            submitButton3[0].click() 

            sleep(6)
            last_height = 0    
            loop = 0
            
            while loop < numberOfTab:
                browserFirefox.execute_script("window.scrollBy(0, 4000);")
                sleep (9)
                new_height = browserFirefox.execute_script("return document.body.scrollHeight")

# =============================================================================
#                Using xpath to search
# =============================================================================
                parser = html.fromstring(browserFirefox.page_source,browserFirefox.current_url)
                hotels = parser.xpath('//div[@class="flex-link-wrap"]')

                for hotel in hotels:
                    counter += 1

                    try:
                        hotel_item = {}
                        address = {}
                        check_in_details = {}
                        scrape_details = {}
                        price_info = {}
                        item = { "Source" : "Expedia.com", }

# =============================================================================
#                Populate Hotel document
# =============================================================================
                        address ['street_name'] = None
                        address ['postal_code'] = None
                        address ['zone'] = None
                        address ['country'] = "Singapore"
					
                        hotel_item ['address'] = address

                        hotelName = hotel.xpath('.//h4 [@class="hotelName fakeLink"]')
                        hotelName = hotelName[0].text_content() if hotelName else None
                                                
                        hotel_item ['hotelName'] = hotelName
                        
                        myquery = { "hotelName" : hotelName }
                        
                        cursor = collection_hotel.find(myquery, { "_id": 1, "hotelName": 1 })
                        if cursor.count() == 0:
                            
                            collection_hotel.insert_one(hotel_item)
                            dbduplicate += 1
                            cursor1 = collection_hotel.find(myquery, { "_id": 1, "hotelName": 1 })
                            
                            for x in cursor1:
                                item ['hotel_info'] = x
                        
                        else:                        
                            for x in cursor:
                                item ['hotel_info'] = x

# =============================================================================
#                Populate check_in_details document
# =============================================================================
                        check_in_details ['check_in_date'] = checkindate
                        check_in_details ['check_in_day'] = str(calendar.day_name[checkindate.weekday()])[:3]
                        check_in_details ['duration'] = durationgap
                        
                        item ['check_in_details'] = check_in_details

# =============================================================================
#                 Populate scrape_details document
# =============================================================================
                        scrape_details ['scrape_day'] = str(calendar.day_name[date.today().weekday()])
                        scrape_details ['scrape_date'] = todayDateImport
                        scrape_details ['days_diff'] = diff_dates(checkindate, todayDateImport)
                        starRating = hotel.xpath('.//strong [@class="star-rating rating-secondary star rating"]/span [@class="visuallyhidden"]')
                        starRating = starRating[0].text_content() if starRating else None

                        if (starRating):
                            starRating1 = re.findall("\d+\.\d+", starRating)
                            scrape_details ['star_rating'] = float(starRating1 [0])                           
                        
                        guestRating = hotel.xpath('.//li [@class="reviewOverall"]/span [@class="visuallyhidden"]')
                        guestRating = guestRating[0].text_content() if guestRating else None                       
                        if (guestRating):
                            guestRating1 = re.findall("\d+\.\d+", guestRating)
                            scrape_details ['guest_rating'] = float(guestRating1 [0]) * 2.0

                        reviewCount = hotel.xpath('.//li [@class="reviewCount fakeLink secondary"]/span [@class="visuallyhidden"]')
                        reviewCount = reviewCount[0].text_content() if reviewCount else None
                        
                        if (reviewCount):
                            reviewCount = reviewCount.replace(",","")
                            reviewCount1 = re.search('\d+', reviewCount) 
                            scrape_details ['review_Count'] = reviewCount1 [0]

                        item ['scrape_details'] = scrape_details

# =============================================================================
#                 Populate price_info document
# =============================================================================
                        try:
                            newPrice = hotel.xpath('.//li [@class="price-breakdown-tooltip price "]/span [@class="actualPrice"]')
                            newPrice1 = newPrice[0].text_content() if newPrice else None
                            newPrice1 = newPrice1.replace("\\n","").replace("$","").strip()
                            price_info ['new_price'] = int (newPrice1)
                            
                        except:
                            try:
                                newPrice = hotel.xpath('.//li [@class="price-breakdown-tooltip price "]/a')
                                newPrice1 = newPrice[0].text_content() if newPrice else None
                                newPrice1 = newPrice1.replace("\\n","").replace("$","").strip()                           
                                price_info ['new_price'] = int (newPrice1)
                            except:
                                continue
                            
                        try: 
                            oldPrice = hotel.xpath('.//a [@class="over-link strikePrice tabAccess"]')
                            oldPrice = oldPrice[0].text_content().replace(",","").strip() if oldPrice else None              
                            oldPrice1 = oldPrice.split(' ')
                            oldPrice1 = oldPrice1[62].replace("\\n","").replace("$","").strip()
                            price_info ['old_price'] = int (oldPrice1)
                            discount = ((int(oldPrice1) - int (newPrice1)) / (int(oldPrice1)))
                            price_info ['discount'] = discount
                            
                        except:
                            price_info ['old_price'] = None
                            
                        item ['price_info'] = price_info
                        collection_price_detail.insert_one(item)
                     
                    except:
                        collection_price_detail.insert_one(item)
                        
                        continue
                    
                if loop < numberOfTab:  
                    nextPage = browserFirefox.find_element_by_xpath('.//button [@class="pagination-next"]/abbr')
                    nextPage.click()
                    loop += 1
                    sleep(4)
     
        browserFirefox.close()
   
        print (checkInDate1)
        print ("No of counter: %d." % counter)
        
    except:
        
        checkindate = checkindate - nextDay    
        checkoutdate = checkindate - duration
        browserFirefox.close()

# =============================================================================
# Delete Duplicate
# =============================================================================
pipeline = [
    {
        u"$group": {
            u"_id": {
                u"hotelName": u"$hotel_info.hotelName",
                u"check_in_date": u"$check_in_details.check_in_date",
                u"new_price": u"$price_info.new_price",
                u"scrape_date": u"$scrape_details.scrape_date",
                u"source": u"$Source"
            },
            u"ids": {
                u"$push": u"$_id"
            },
            u"count": {
                u"$sum": 1.0
            }
        }
    }, 
    {
        u"$match": {
            u"count": {
                u"$gt": 1.0
            }
        }
    }
]

cursor = collection_price_detail.aggregate(pipeline)

response = []
for doc in cursor:
    del doc["ids"][0]
    for id in doc["ids"]:
        response.append(id)

collection_price_detail.delete_many({"_id": {"$in": response}})

# =============================================================================
# Close Connection
# =============================================================================
conn.close()










from datetime import date
from datetime import timedelta

from re import findall
from lxml import html
from time import sleep
import calendar
import datetime
from pymongo import MongoClient

from selenium import webdriver

# =============================================================================
# Constant
# =============================================================================
scrollDown = 15
counter = 0
durationgap = 3

todayDate = date.today().strftime("%d/%m/%Y")
todayDateImport = datetime.datetime.utcnow()
checkindate = datetime.datetime(2018, 8, 31)
nextDay = timedelta(days=1)
duration = timedelta(days=3)
endDate = datetime.datetime(2019, 9, 1)
searchKey = "Singapore, Singapore"

# =============================================================================
# Simple Function
# =============================================================================
def diff_dates(date1, date2):
    return abs(date2-date1).days

def get_zone (number):
    if number < 42:
        return "Central"
    elif number < 53:
        return "East"
    elif number < 56:
        return "North-East"
    elif number < 60:
        return "Central"
    elif number < 72:
        return "West"
    elif number < 77:
        return "North"
    elif number < 75:
        return "North-East"
    elif number < 79:
        return "North"
    else:
        return "North-East"
    
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
    checkInDate = checkindate.strftime("%d/%m/%Y")
    checkOutDate = checkoutdate.strftime("%d/%m/%Y")
    
    try:
        browserFirefox = webdriver.Firefox()
        browserFirefox.get('http://www.hotels.com')
        
        try:
            browserFirefox.find_element_by_xpath('//button[contains(@class,"cta widget-overlay")]').click()
        except:
            pass
        
        searchKeyElement = browserFirefox.find_elements_by_xpath('//input[contains(@id,"destination")]')
        checkInElement =browserFirefox.find_elements_by_xpath('//input[contains(@class,"check-in")]')
        checkOutElement = browserFirefox.find_elements_by_xpath('//input[contains(@class,"check-out")]')
        submitButton = browserFirefox.find_elements_by_xpath('//button[@type="submit"]')
    
        if searchKeyElement and checkInElement and checkOutElement:
            searchKeyElement[0].send_keys(searchKey)
            sleep(2)
            randomClick = browserFirefox.find_elements_by_xpath('//h1')
            if randomClick:
                randomClick[0].click()
            checkInElement[0].clear()
            checkInElement[0].send_keys(checkInDate)
            checkOutElement[0].clear()
            checkOutElement[0].send_keys(checkOutDate)

            if randomClick:
                randomClick[0].click()
            submitButton[0].click()
            sleep(4)
            
            last_height = 0    
            count = 0
            
            while True:
                browserFirefox.execute_script("window.scrollBy(0, 4000);")    
                sleep(3)
                new_height = browserFirefox.execute_script("return document.body.scrollHeight")
                if new_height == last_height:
                    break
                last_height = new_height
                count = count + 1
                if count == scrollDown:
                    break
        
# =============================================================================
#             Using xpath to search
# =============================================================================
            parser = html.fromstring(browserFirefox.page_source,browserFirefox.current_url)
            hotels = parser.xpath('//div[@class="hotel-wrap"]')
                       
            for hotel in hotels:
                counter += 1

                hotel_item = {}
                address = {}
                check_in_details = {}
                scrape_details = {}
                price_info = {}
                item = { "Source" : "Hotel.com", }
                    
# =============================================================================
#                Populate Hotel document
# =============================================================================
                address_info = hotel.xpath('.//span[contains(@class,"street-address")]')
                address_info = "".join([x.text_content() for x in address_info]) if address_info else None
                address_info = address_info.replace(",","")
  
                postalCode = hotel.xpath('.//span[contains(@class,"postal-code")]')
                postalCode = postalCode[0].text_content().replace(",","").strip() if postalCode else None

                countryName = hotel.xpath('.//span[contains(@class,"country-name")]')
                countryName = countryName[0].text_content().replace(",","").strip() if countryName else None               
               
                if (countryName == "Singapore"):
                    address ['country'] = countryName
                else:
                    continue
                    
                address ['street_name'] = address_info
                address ['postal_code'] = postalCode
                
                if postalCode:
                    address ['zone'] = get_zone ((int(postalCode)//10000))                    
                else:
                    address ['zone'] = None
 
                
                hotel_item ['address'] = address
                
                hotelName = hotel.xpath('.//h3/a')
                hotelName = hotelName[0].text_content() if hotelName else None

                hotel_item ['hotelName'] = hotelName
                    
                myquery = { "hotelName" : hotelName }
                
                cursor = collection_hotel.find(myquery, { "_id": 1, "hotelName": 1 })
                if cursor.count() == 0:                    
                    collection_hotel.insert_one(hotel_item)
                    cursor1 = collection_hotel.find(myquery, { "_id": 1, "hotelName": 1 })
                    
                    for x in cursor1:
                        item ['hotel_info'] = x
                
                else:  
                    collection_hotel.update_one({'hotelName': hotelName},{'$set': {'address' : address}})
                    
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

                starRating = hotel.xpath('.//div[@class="star-rating-text star-rating-text-strong"]')
                starRating = starRating[0].text_content().replace(",","").strip() if starRating else None
                
                if starRating == None:
                    starRating = hotel.xpath('.//div[@class="star-rating-text"]')
                    starRating = starRating[0].text_content().replace(",","").strip() if starRating else None
                
                if starRating:
                    starRating1 = findall(r"[-+]?\d*\.\d+|\d+", starRating)
                    scrape_details ['star_rating'] = float(starRating1[0])
                else:
                    scrape_details ['star_rating'] = starRating
                
                guestRating = hotel.xpath('.//span[contains(@class,"guest-rating-value")]')
                guestRating = guestRating[0].text_content().replace(",","").strip() if guestRating else None
                scrape_details ['guest_rating'] = guestRating

                numReviews = hotel.xpath('.//span[contains(@class, "ta-total-reviews")]')
                numReviews = numReviews[0].text_content().replace(" reviews","").replace(",","").strip() if numReviews else None
                scrape_details ['review_Count'] = numReviews

                item ['scrape_details'] = scrape_details
                
# =============================================================================
#                 Populate price_info document
# =============================================================================
                try:
                    price = hotel.xpath('.//div[@class="price"]/a//ins')
                    price = price[0].text_content().replace(",","").strip() if price else None
                    if price==None:
                        price = hotel.xpath('.//div[@class="price"]/a')
                        price = price[0].text_content().replace(",","").strip() if price else None
                    price = findall('([\d\.]+)',price) if price else None
                    price = price[0] if price else None
                
                    price_info ['new_price'] = int(price)
                    
                except:
                    continue
                
                try: 
                    oldPrice = hotel.xpath('.//span[@class="old-price-cont"]/del')
                    oldPrice = oldPrice[0].text_content().replace(",","").replace("S$","").strip() if oldPrice else None
                    price_info ['old_price'] = int(oldPrice)
                    discount = ((int(oldPrice) - int (price)) / (int(oldPrice)))
                    price_info ['discount'] = discount
                    
                except:
                    price_info ['old_price'] = None                
               
                item ['price_info'] = price_info
  
                collection_price_detail.insert_one(item)
            
            browserFirefox.close()
            
            print (checkInDate)
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



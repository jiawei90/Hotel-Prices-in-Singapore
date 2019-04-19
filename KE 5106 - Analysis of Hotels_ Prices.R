install.packages("ggplot2")
install.packages("dplyr")
install.packages("maps")
install.packages("ggmap")
install.packages("lubridate")
install.packages("gridExtra")
install.packages("data.table")
install.packages("RMongo")
install.packages("date")
install.packages("sqldf")
install.packages("quantreg")
install.packages("directlabels")
install.packages("ggrepel")

library(date)
library(sqldf)
library(ggplot2)
library(dplyr)
library(plyr)
library(mongolite)
library(lubridate)
library(gridExtra)
library(data.table)
library("reshape2")
library(scales)
library(quantreg)
library(grid)
library(directlabels)
library(ggrepel)

setwd("C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo")

##### CONNECT TO MONGODB #####
price_details_aws <- mongo(collection = "price_details", db = "ke5106", url = "mongodb://54.169.201.91:27017/", verbose = TRUE)
hotel_details_aws <- mongo(collection = "hotel", db = "ke5106", url = "mongodb://54.169.201.91:27017/", verbose = TRUE )

##### MONGO QUERY FOR HOTELS FROM EXPEDIA.COM AND HOTELS.COM #####
retrieve_expedia <- price_details_aws$aggregate(
'[{
  "$match": {
    "$and": [
      {
        "scrape_details.scrape_date": {"$gte": { "$date" : "2018-08-08T00:00:00Z" },"$lt": { "$date" : "2018-08-15T00:00:00Z" }}
      },
      { 
        "Source": { "$eq":"Expedia.com" }
      }
      ]
  }
},
  
  {
    "$group": {
      "_id": {
        "hotel": "$hotel_info.hotelName"
        },
      "scrape_date": { "$max": "$scrape_details.scrape_date" },
      "star_rating": { "$max": "$scrape_details.star_rating"},
      "guest_rating" : { "$max": "$scrape_details.guest_rating"},
      "review_count" : { "$max": "$scrape_details.review_Count"}
    }
}]'
)
retrieve_expedia_1 <- retrieve_expedia$`_id`$hotel
retrieve_expedia_2 <- retrieve_expedia$scrape_date
retrieve_expedia_3 <- retrieve_expedia$star_rating
retrieve_expedia_4 <- retrieve_expedia$guest_rating
retrieve_expedia_5 <- retrieve_expedia$review_count
retrieve_expedia <- data.frame(retrieve_expedia_1, retrieve_expedia_2, retrieve_expedia_3, retrieve_expedia_4, retrieve_expedia_5)
names(retrieve_expedia) <- c("hotelName", "scrapeDate", "star.rating", "guest.rating", "No..of.reviews")
retrieve_expedia$hotelName <- as.character(retrieve_expedia$hotelName)
rm("retrieve_expedia_1", "retrieve_expedia_2", "retrieve_expedia_3", "retrieve_expedia_4", "retrieve_expedia_5")

retrieve_hotel <- price_details_aws$aggregate(
  '[{
  "$match": {
  "$and": [
  {
  "scrape_details.scrape_date": {"$gte": { "$date" : "2018-08-08T00:00:00Z" },"$lt": { "$date" : "2018-08-15T00:00:00Z" }}
  },
  { 
  "Source": { "$eq":"Hotels.com" }
  }
  ]
  }
  },
  
  {
  "$group": {
  "_id": {
  "hotel": "$hotel_info.hotelName"
  },
  "scrape_date": { "$max": "$scrape_details.scrape_date" },
  "star_rating": { "$max": "$scrape_details.star_rating"},
  "guest_rating" : { "$max": "$scrape_details.guest_rating"},
  "review_count" : { "$max": "$scrape_details.review_Count"}
  }
  }]'
)

retrieve_hotel_1 <- retrieve_hotel$`_id`$hotel
retrieve_hotel_2 <- retrieve_hotel$scrape_date
retrieve_hotel_3 <- retrieve_hotel$star_rating
retrieve_hotel_4 <- retrieve_hotel$guest_rating
retrieve_hotel_5 <- retrieve_hotel$review_count
retrieve_hotel <- data.frame(retrieve_hotel_1, retrieve_hotel_2, retrieve_hotel_3, retrieve_hotel_4, retrieve_hotel_5)
names(retrieve_hotel) <- c("hotelName", "scrapeDate", "star.rating", "guest.rating", "No..of.reviews")
retrieve_hotel$hotelName <- as.character(retrieve_hotel$hotelName)
rm("retrieve_hotel_1", "retrieve_hotel_2", "retrieve_hotel_3", "retrieve_hotel_4", "retrieve_hotel_5")

# IDENTIFY LIST OF UNIQUE HOTELS
hotel_data <- hotel_details_aws$find('{}')
uniqueHotels <- hotel_data$hotelName

##### UPDATE HOTEL RATING #####
# INITIALIZE EMPTY HOTEL LIST WHICH WILL BE THE MASTER
myHotels <- data.frame(source = character(), hotelName = character(), star_rating = double(), guest_rating = double(), numReview = integer())

for (i in 1:length(uniqueHotels))
{
  result_expedia <- subset(retrieve_expedia, hotelName == uniqueHotels[i])
  if(nrow(result_expedia) == 0)
  {
    result_hotels <- subset(retrieve_hotel, hotelName == uniqueHotels[i])
    if(nrow(result_hotels) == 0)
    {
      toAppend <- data.frame(source = "N.A", hotelName = uniqueHotels[i], star_rating = 0.0, guest_rating = 0.0, numReview = 0)
      myHotels <- rbind(myHotels, toAppend)
    }
    else
    {
      toAppend <- data.frame(source = "Hotels.com", hotelName = uniqueHotels[i], star_rating = result_hotels$star.rating[1], guest_rating = result_hotels$guest.rating[1], numReview = result_hotels$No..of.reviews[1])
      myHotels <- rbind(myHotels, toAppend)
    }
  }
  else
  {
    toAppend <- data.frame(source = "Expedia.com", hotelName = uniqueHotels[i], star_rating = result_expedia$star.rating[1], guest_rating = result_expedia$guest.rating[1], numReview = result_expedia$No..of.reviews[1])
    myHotels <- rbind(myHotels, toAppend)
  }
  print (i)
}
rm(list = c('result_expedia', 'result_hotels', 'toAppend', 'hotel_data', 'retrieve_expedia', 'retrieve_hotel'))

##### COMPUTE PERCENTILE #####
# SET ALL NULL VALUES (WHICH SHOULD EXIST) TO ZERO
percentileList <- c(0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9)

# MAKE SURE ALL COLUMNS ALL NUMERIC
myHotels$numReview <- as.numeric(as.character(myHotels$numReview))
myHotels$guest_rating <- as.numeric(as.character(myHotels$guest_rating))
myHotels$star_rating <- as.numeric(as.character(myHotels$star_rating))
myHotels[is.na(myHotels)] <- 0
str(myHotels$numReview)
str(myHotels$star_rating)
str(myHotels$guest_rating)

# COMPUTE PERCENTILE
starPercentile <- quantile(myHotels$star_rating, probs = percentileList)
guestPercentile <- quantile(myHotels$guest_rating, probs = percentileList)
reviewPercentile <- quantile(myHotels$numReview, probs = percentileList)

##### UPDATE HOTEL CATEGORY #####
###  LUXURIOUS & POPULAR HOTELS ###  = 5 STARS       ###  >= 80TH GUEST RATING        ###  >= 70TH NO. REVIEWS
###  BUDGET HOTELS              ###  <= 30TH sTARS   ###  <= 30TH GUEST RATING        ###  <= 30TH NO. REVIEWS
###  DECENT HOTELS              ###                  ### 30TH > GUEST RATING <= 50TH  ###
###  COMFORTABLE HOTELS         ###  ALL OTHERS

luxuriousHotels <- subset(myHotels, star_rating == 5.0 & guest_rating >= guestPercentile[8] & numReview >= reviewPercentile[7])

budgetHotels <- subset(myHotels, star_rating <= starPercentile[3] & guest_rating <= guestPercentile[3])

decentHotels <- subset(myHotels, star_rating <= starPercentile[5])
decentHotels <- sqldf("SELECT * FROM decentHotels EXCEPT SELECT * FROM budgetHotels")

comfortableHotels <- sqldf(" SELECT * FROM myHotels EXCEPT SELECT * FROM luxuriousHotels")
comfortableHotels <- sqldf(" SELECT * FROM comfortableHotels EXCEPT SELECT * FROM budgetHotels")
comfortableHotels <- sqldf(" SELECT * FROM comfortableHotels EXCEPT SELECT * FROM decentHotels")

budgetHotels$Category <- rep("Budget", nrow(budgetHotels))
decentHotels$Category <- rep("Decent", nrow(decentHotels))
comfortableHotels$Category <- rep("Comfortable", nrow(comfortableHotels))
luxuriousHotels$Category <- rep("Luxurious", nrow(luxuriousHotels))

myHotels <- rbind(budgetHotels, decentHotels, comfortableHotels, luxuriousHotels)
toUpload <- data.frame(myHotels$hotelName, myHotels$Category)

# UPLOAD TEMPORARY COLLECTION 
hotel_categories_aws <- mongo(collection = "hotel categories", db = "ke5106", url = "mongodb://54.169.201.91:27017/", verbose = TRUE)
hotel_categories_aws$insert(toUpload)

##### BAR CHART - HOTEL CATEGORIES #####
myHotels$Category <- factor(myHotels$Category, levels = c("Luxurious", "Comfortable", "Decent", "Budget"))
bar_category <- ggplot(data = myHotels, aes(x=Category), fill = "blue")
bar_category + geom_bar(fill="dark blue") + xlab("Hotel Category") + ylab("Count of Hotels") + 
  theme_classic() + ggtitle("Distribution of Hotels based on Category") + 
  theme(axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5))

ggsave(filename="Distribution of Hotels based on Category.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 15, height = 10, units = "cm")


##### LINE CHART - PRICE BY SOURCE #####
# QUERY FROM MONGO DB
getPricesByCheckInDateSource <- price_details_aws$aggregate(
  '[{
  "$lookup":{
  "from":"hotel categories",
  "localField":"hotel_info.hotelName",
  "foreignField":"myHotels_hotelName",
  "as":"lookedUp"
  }},
  {
  "$replaceRoot":{
  "newRoot":{
  "$mergeObjects":[
  {
  "$arrayElemAt":[
  "$lookedUp",
  0]},
  "$$ROOT"
  ]}}},
  {
  "$group":{
  "_id":{
  "Source":"$Source",
  "Check_in_Date":{
  "$dateToString":{
  "format":"%Y-%m-%d",
  "date":"$check_in_details.check_in_date"
  }}},
  "Average_Price":{
  "$avg":"$price_info.new_price"
  }}}]'
)

# MODIFYING DATA TYPES TO PLOT THE GRAPHS
getPricesByCheckInDateSource1 <- getPricesByCheckInDateSource$`_id`$Source
getPricesByCheckInDateSource2 <- getPricesByCheckInDateSource$`_id`$Check_in_Date
getPricesByCheckInDateSource3 <- getPricesByCheckInDateSource$Average_Price
avgPrice_by_Source <- data.frame(getPricesByCheckInDateSource1, getPricesByCheckInDateSource2, getPricesByCheckInDateSource3)
rm("getPricesByCheckInDateSource", "getPricesByCheckInDateSource1", "getPricesByCheckInDateSource2", "getPricesByCheckInDateSource3")
names(avgPrice_by_Source) <- c("Source", "check.in2", "daily_mean_source")

avgPrice_by_Source$check.in2 <- as.Date(as.character(avgPrice_by_Source$check.in2))

price_by_day_source <- ggplot(data = avgPrice_by_Source, aes(x=check.in2, y=daily_mean_source, colour = Source))
price_by_day_source + geom_line() + theme_classic() + xlab("Check-in Dates") + ylab("Price per night") + 
  ggtitle("Distribution of Daily Hotels' Prices by Booking Websites") +
  scale_x_date(breaks = date_breaks("months"), labels = date_format("%b-%y"), limits = as.Date(c('2018-09-01','2019-08-01'))) +
  theme(axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5))

ggsave(filename="Distribution of Daily Hotels' Prices by Booking Websites.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 25, height = 10, units = "cm")

var(subset(avgPrice_by_Source, Source == "Expedia.com")$daily_mean_source)
var(subset(avgPrice_by_Source, Source == "Hotels.com")$daily_mean_source)


##### LINE CHART - PRICE BY DATE AVG ACROSS BOTH SITES #####
# QUERY FROM MONGO DB
getPriceByDate <- price_details_aws$aggregate(
  '[{
  "$lookup":{
  "from":"hotel categories",
  "localField":"hotel_info.hotelName",
  "foreignField":"myHotels_hotelName",
  "as":"lookedUp"
  }},{
  "$replaceRoot":{
  "newRoot":{
  "$mergeObjects":[
  {
  "$arrayElemAt":[
  "$lookedUp",
  0]},
  "$$ROOT"
  ]}}},
  {
  "$group":{
  "_id":{
  "Category":"$myHotels_Category",
  "Check_in_Date":{
  "$dateToString":{
  "format":"%Y-%m-%d",
  "date":"$check_in_details.check_in_date"
  }}},
  "Average_Price":{
  "$avg":"$price_info.new_price"
  }}}]'
)

# MODIFYING DATA TYPES TO PLOT THE GRAPHS
getPriceByDate1 <- getPriceByDate$`_id`$Check_in_Date
getPriceByDate2 <- getPriceByDate$`_id`$Category
getPriceByDate3 <- getPriceByDate$Average_Price
avgPrice_by_day_category <- data.frame(getPriceByDate1, getPriceByDate2, getPriceByDate3)
names(avgPrice_by_day_category) <- c("check.in2", "Category", "daily_mean")
rm("getPriceByDate1", "getPriceByDate2", "getPriceByDate3", "getPriceByDate")

avgPrice_by_day_category$check.in2 <- as.Date(as.character(avgPrice_by_day_category$check.in2))
avgPrice_by_day_category$Category <- factor(avgPrice_by_day_category$Category, levels = c("Luxurious", "Comfortable", "Decent", "Budget"))

price_by_day_line <- ggplot(data = avgPrice_by_day_category, aes(x=check.in2, y=daily_mean, colour = Category))
price_by_day_line + geom_line() + theme_classic() + xlab("Check-in Dates") + ylab("Price per night") +
  ggtitle("Average Daily Hotel Prices vs Check In Date") +
  scale_color_discrete(name = "Hotel Category") + 
  scale_x_date(breaks = date_breaks("months"), labels = date_format("%b-%y"), limits = as.Date(c('2018-09-01','2019-08-01'))) +
  theme(axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5))

ggsave(filename="Average Daily Hotel Prices vs Check In Date.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 25, height = 10, units = "cm")

var(subset(avgPrice_by_day_category, Category == "Luxurious")$daily_mean)
var(subset(avgPrice_by_day_category, Category == "Comfortable")$daily_mean)
var(subset(avgPrice_by_day_category, Category == "Decent")$daily_mean)
var(subset(avgPrice_by_day_category, Category == "Budget")$daily_mean)


##### BOXPLOT - DAILY PRICES BY HOTEL CATEGORIES #####
category_boxplot <- ggplot(data = avgPrice_by_day_category, aes(x=Category, y=daily_mean, colour=Category))
category_boxplot + geom_boxplot(size=0.3, alpha=0.01) + geom_jitter() + 
  xlab("Hotel Category") + ylab("Price per night") + theme_classic() +
  ggtitle("Distribution of Daily Hotels' Prices by Hotel's Category") +
  scale_color_discrete(name = "Hotel Category") + 
  theme(axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5)) +
  coord_cartesian(ylim = range(boxplot(avgPrice_by_day_category$daily_mean, plot=FALSE)$stats)*c(.9, 1))

ggsave(filename="Distribution of Daily Hotels' Prices by Hotel's Category.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 25, height = 20, units = "cm")

##### LINE CHART - PRICES BY MONTH #####
getPriceByMonth <- price_details_aws$aggregate(
  '[{
  "$lookup":{
  "from":"hotel categories",
  "localField":"hotel_info.hotelName",
  "foreignField":"myHotels_hotelName",
  "as":"lookedUp"
  }},{
  "$replaceRoot":{
  "newRoot":{
  "$mergeObjects":[
  {
  "$arrayElemAt":[
  "$lookedUp",
  0]},
  "$$ROOT"
  ]}}},
  {
  "$group":{
  "_id":{
  "Category":"$myHotels_Category",
  "Month":{
  "$month":"$check_in_details.check_in_date"
  }},
  "Average_Price":{
  "$avg":"$price_info.new_price"
  }}}]'
)

getPriceByMonth1 <- getPriceByMonth$`_id`$Month
getPriceByMonth2 <- getPriceByMonth$`_id`$Category
getPriceByMonth3 <- getPriceByMonth$Average_Price
avgPrice_by_month_category <- data.frame(getPriceByMonth1, getPriceByMonth2, getPriceByMonth3)

names(avgPrice_by_month_category) <- c("month", "Category", "monthly_mean")
rm("getPriceByMonth1", "getPriceByMonth2", "getPriceByMonth3", "getPriceByMonth")

avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 1, "Jan 19", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 2, "Feb 19", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 3, "Mar 19", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 4, "Apr 19", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 5, "May 19", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 6, "Jun 19", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 7, "Jul 19", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 8, "Aug 19", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 9, "Sep 18", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 10, "Oct 18", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 11, "Nov 18", avgPrice_by_month_category$month)
avgPrice_by_month_category$month <- ifelse(avgPrice_by_month_category$month == 12, "Dec 18", avgPrice_by_month_category$month)

avgPrice_by_month_category$Category <- factor(avgPrice_by_month_category$Category, levels = c("Luxurious", "Comfortable", "Decent", "Budget"))
avgPrice_by_month_category$month <- factor(avgPrice_by_month_category$month, levels = c("Sep 18", "Oct 18", "Nov 18", "Dec 18", "Jan 19", "Feb 19", "Mar 19", "Apr 19", "May 19", "Jun 19", "Jul 19", "Aug 19"))

price_by_month_line <- ggplot(data = avgPrice_by_month_category, aes(x=month, y=monthly_mean, colour=Category, group = Category))
price_by_month_line + geom_point() + geom_line() + theme_classic() + xlab("Check-in Month") + ylab("Price per night") +
  ggtitle("Average Daily Hotel Prices vs Check In Month") +
  scale_color_discrete(name = "Hotel Category") + 
  theme(axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5))

ggsave(filename="Average Daily Hotel Prices vs Check In Month.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 25, height = 10, units = "cm")

##### LINE CHART - PRICES BY CHECK IN DAY #####
# QUERY FROM MONGODB
getPriceByCheckInDay <- price_details_aws$aggregate(
  '[{
  "$lookup":{
  "from":"hotel categories",
  "localField":"hotel_info.hotelName",
  "foreignField":"myHotels_hotelName",
  "as":"lookedUp"
  }},{
  "$replaceRoot":{
  "newRoot":{
  "$mergeObjects":[
  {
  "$arrayElemAt":[
  "$lookedUp",
  0]},
  "$$ROOT"
  ]}}},
  {
  "$group":{
  "_id":{
  "Category":"$myHotels_Category",
  "Check_in_Day":"$check_in_details.check_in_day"
  },
  "Average_Price":{
  "$avg":"$price_info.new_price"
  }}}]'
)

# MODIFYING DATA TYPES TO PLOT THE GRAPHS
getPriceByCheckInDay1 <- getPriceByCheckInDay$`_id`$Check_in_Day
getPriceByCheckInDay2 <- getPriceByCheckInDay$`_id`$Category
getPriceByCheckInDay3 <- getPriceByCheckInDay$Average_Price
avgPrice_by_checkInDay <- data.frame(getPriceByCheckInDay1, getPriceByCheckInDay2, getPriceByCheckInDay3)

names(avgPrice_by_checkInDay) <- c("Check.in.Day", "Category", "mean_by_day")
rm("getPriceByCheckInDay1", "getPriceByCheckInDay2", "getPriceByCheckInDay3", "getPriceByCheckInDay")

avgPrice_by_checkInDay$Check.in.Day <- factor(avgPrice_by_checkInDay$Check.in.Day, levels = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"))
avgPrice_by_checkInDay$Category <- factor(avgPrice_by_checkInDay$Category, levels = c("Luxurious", "Comfortable", "Decent", "Budget"))

price_by_checkInDay <- ggplot(data = avgPrice_by_checkInDay, aes(x=Check.in.Day, y=mean_by_day, colour = Category, group = Category))
price_by_checkInDay + geom_point() + geom_line() + theme_classic() + xlab("Check In Day") + ylab("Price per night") +
  ggtitle("Average Daily Hotel Prices vs Check In Day") +
  geom_dl(aes(label = Category), method = list(dl.trans(x=x+.2), "last.points"), cex = 0.9) +
  theme(legend.position = "none",
        axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5))

ggsave(filename="Average Daily Hotel Prices vs Check In Day.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 35, height = 15, units = "cm")


##### LINE CHART - PRICES BY BOOKING DAY #####
# QUERY FROM MONGODB
getPriceByBookingDay <- price_details_aws$aggregate(
  '[{
  "$lookup":{
  "from":"hotel categories",
  "localField":"hotel_info.hotelName",
  "foreignField":"myHotels_hotelName",
  "as":"lookedUp"
  }},{
  "$replaceRoot":{
  "newRoot":{
  "$mergeObjects":[
  {
  "$arrayElemAt":[
  "$lookedUp",
  0]},
  "$$ROOT"
  ]}}},{
  "$group":{
  "_id":{
  "Category":"$myHotels_Category",
  "Booking_date":"$scrape_details.scrape_day"
  },
  "Average_Price":{
  "$avg":"$price_info.new_price"
  }}}]'
)

# MODIFYING DATA TYPES TO PLOT THE GRAPHS
getPriceByBookingDay1 <- getPriceByBookingDay$`_id`$Booking_date
getPriceByBookingDay2 <- getPriceByBookingDay$`_id`$Category
getPriceByBookingDay3 <- getPriceByBookingDay$Average_Price
avgPrice_by_BookingDay <- data.frame(getPriceByBookingDay1, getPriceByBookingDay2, getPriceByBookingDay3)

names(avgPrice_by_BookingDay) <- c("Scrape.Day", "Category", "mean_scrape")
rm("getPriceByBookingDay1", "getPriceByBookingDay2", "getPriceByBookingDay3", "getPriceByBookingDay")

avgPrice_by_BookingDay$Scrape.Day <- factor(avgPrice_by_BookingDay$Scrape.Day, levels = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"))
avgPrice_by_BookingDay$Category <- factor(avgPrice_by_BookingDay$Category, levels = c("Luxurious", "Comfortable", "Decent", "Budget"))

price_by_BookingDay <- ggplot(data = avgPrice_by_BookingDay, aes(x=Scrape.Day, y=mean_scrape, colour = Category, group = Category))
price_by_BookingDay + geom_point() + geom_line() + theme_classic() + xlab("Booking Day") + ylab("Price per night") +
  ggtitle("Average Daily Hotel Prices vs Booking Day") +
  geom_dl(aes(label = Category), method = list(dl.trans(x=x+.2), "last.points"), cex = 0.9) +
  theme(legend.position = "none",
        axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5))

ggsave(filename="Average Daily Hotel Prices vs Booking Day.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 35, height = 15, units = "cm")


##### LINE CHART - DISCOUNTS BY CHECK IN DAY #####
# QUERY FROM MONGODB
getDiscountByCheckInDay <- price_details_aws$aggregate(
  '[{
  "$lookup":{
  "from":"hotel categories",
  "localField":"hotel_info.hotelName",
  "foreignField":"myHotels_hotelName",
  "as":"lookedUp"
  }},{
  "$replaceRoot":{
  "newRoot":{
  "$mergeObjects":[
  {
  "$arrayElemAt":[
  "$lookedUp",
  0]},
  "$$ROOT"
  ]}}},{
  "$group":{
  "_id":{
  "Category":"$myHotels_Category",
  "Check_in_Day":"$check_in_details.check_in_day"
  },
  "Average_Discount":{
  "$avg":"$price_info.discount"
  }}}]'
)

# MODIFYING DATA TYPES TO PLOT THE GRAPHS
getDiscountByCheckInDay1 <- getDiscountByCheckInDay$`_id`$Check_in_Day
getDiscountByCheckInDay2 <- getDiscountByCheckInDay$`_id`$Category
getDiscountByCheckInDay3 <- getDiscountByCheckInDay$Average_Discount
avgDiscount_by_checkInDay <- data.frame(getDiscountByCheckInDay1, getDiscountByCheckInDay2, getDiscountByCheckInDay3)

names(avgDiscount_by_checkInDay) <- c("Check.in.Day", "Category", "mean_by_day")
rm("getDiscountByCheckInDay1", "getDiscountByCheckInDay2", "getDiscountByCheckInDay3", "getDiscountByCheckInDay")

avgDiscount_by_checkInDay$Check.in.Day <- factor(avgPrice_by_checkInDay$Check.in.Day, levels = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"))
avgDiscount_by_checkInDay$Category <- factor(avgPrice_by_checkInDay$Category, levels = c("Luxurious", "Comfortable", "Decent", "Budget"))

discount_by_checkInDay <- ggplot(data = avgDiscount_by_checkInDay, aes(x=Check.in.Day, y=mean_by_day, colour = Category, group = Category))
discount_by_checkInDay + geom_point() + geom_line() + theme_classic() + xlab("Check In Day") + ylab("Discount") +
  ggtitle("Average Discount vs Check In Day") +
  geom_dl(aes(label = Category), method = list(dl.trans(x=x+.2), "last.points"), cex = 0.9) +
  theme(legend.position = "none",
        axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5))

ggsave(filename="Average Discount vs Check In Day.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 35, height = 15, units = "cm")


##### LINE CHART - PRICES BY DAYS DIFFERENCE #####
# QUERY FROM MONGODB
getPricesByDaysDifference <- price_details_aws$aggregate(
  '[{
  "$lookup":{
  "from":"hotel categories",
  "localField":"hotel_info.hotelName",
  "foreignField":"myHotels_hotelName",
  "as":"lookedUp"
  }},{
  "$replaceRoot":{
  "newRoot":{
  "$mergeObjects":[
  {
  "$arrayElemAt":[
  "$lookedUp",
  0]},
  "$$ROOT"
  ]}}},
  {
  "$group":{
  "_id":{
  "Category":"$myHotels_Category",
  "Days Diff":"$scrape_details.days_diff"
  },
  "Average_Price":{
  "$avg":"$price_info.new_price"
  }}}]'
)

# MODIFYING DATA TYPES TO PLOT THE GRAPHS
getPricesByDaysDifference1 <- getPricesByDaysDifference$`_id`$`Days Diff`
getPricesByDaysDifference2 <- getPricesByDaysDifference$`_id`$Category
getPricesByDaysDifference3 <- getPricesByDaysDifference$Average_Price
avgPrice_by_daysDiff <- data.frame(getPricesByDaysDifference1, getPricesByDaysDifference2, getPricesByDaysDifference3)

names(avgPrice_by_daysDiff) <- c("Days.Difference", "Category", "mean_by_day")
rm("getPricesByDaysDifference1", "getPricesByDaysDifference2", "getPricesByDaysDifference3", "getPricesByDaysDifference")

avgPrice_by_daysDiff$Category <- factor(avgPrice_by_daysDiff$Category, levels = c("Luxurious", "Comfortable", "Decent", "Budget"))

price_by_daysDiff <- ggplot(data = avgPrice_by_daysDiff, aes(x=Days.Difference, y=mean_by_day, colour = Category, group = Category))
price_by_daysDiff +  geom_line() + theme_classic() + xlab("Difference in Check-in and Booking Dates") + ylab("Price per night") +
  ggtitle("Average Daily Hotel Prices vs Differences in Check-in & Booking dates") +
  scale_x_continuous(breaks=seq(0,400,20)) +
  theme(axis.title.x=element_text(colour = "Black", size=12), 
        axis.title.y=element_text(colour = "Black", size=12),
        plot.title = element_text(colour="Black", size=18, family = "Arial", hjust=0.5))

ggsave(filename="Average Daily Hotel Prices vs Differences in Check-in & Booking dates.png", plot = last_plot(), path = "C:\\Users\\chee.jw\\Desktop\\NUS matters\\R to Mongo\\Charts Output", width = 60, height = 20, units = "cm")

##### END OF ANALYSIS #####
# Remove temp collection
hotel_categories_aws$drop()
print("End of Analysis")


#loading dependencies

options(java.parameters = "- Xmx1024m")
options(scipen=999)
options(shiny.maxRequestSize=1000*1024^2)
library(shinyBS)
library(shiny)
library(prob)
library(dplyr)
library(shinydashboard)
library(RColorBrewer)
library(shinyjs)
library(readxl)
library(DT)
library(writexl)
library(data.table)
library(openxlsx)
library(shinyFiles)
library(xlsx)
library(plyr)
library(shinyjqui)
library(stringr)
library(editData)
library(V8)
library(fs)
library(stringi)
library(curl)
library(tidyr)
library(diffr)
library(shinyalert)

QA<-fread("./Default/Documents/QA.csv",header=TRUE)

title <- tags$a(href='https://www.google.com',
                             tags$img(src="nissan-logo-mobile.png", height = '107%', width = '100%'),tags$head(HTML("<title>Data Synergy</title>"))
                 ,target="_blank")

###-------------------------------------------------

#ShinyDashboard
header <- dashboardHeader(title =title, 
                                    
                                 tags$li(class = "dropdown", uiOutput("logout")))
sidebar <- dashboardSidebar(uiOutput("sidebarpanel"))
body <- dashboardBody(useShinyjs(), useShinyalert(),shinyjs::extendShinyjs(text =  "shinyjs.refresh = function() { history.go(0); }"),tags$head(
  tags$link(rel = "stylesheet", type = "text/css", href = "style1.css")
),uiOutput("body"))

#log-in ids
login_details <- data.frame(user = c("nissan_user"),
                            pswd = c("nissan_pass"))
login <- div(id="login_box",box(
  id="login_id",
  
  textInput("userName", "Username"),
  passwordInput("passwd", "Password"),
  br(),
  actionButton("Login", "Log in")
))
##

#ui
ui <-dashboardPage(header, sidebar, body)
##


#server
server <- function(input, output,session) {
  df_data_reactive<-reactiveValues()
  volumes <- c(root='.')
  shinyDirChoose(input, "directory", roots = volumes, session = session, restrictions = system.file(package = "base"))
  shinyFileChoose(input, "file", roots = volumes, session = session)
  
  login.page = paste(
    isolate(session$clientData$url_protocol),
    "//",
    isolate(session$clientData$url_hostname),
    ":",
    isolate(session$clientData$url_port),
    sep = ""
  )
  
  
  USER <- reactiveValues(Logged = F)
  observe({
    if (USER$Logged == FALSE) {
      if (!is.null(input$Login)) {
        if (input$Login > 0) {
          Username <- isolate(input$userName)
          Password <- isolate(input$passwd)
          Id.username <- which(login_details$user %in% Username)
          Id.password <- which(login_details$pswd %in% Password)
          if (length(Id.username) > 0 & length(Id.password) > 0){
            if (Id.username == Id.password) {
              USER$Logged <- TRUE
            }
          }
        }
      }
    }
  })
  
  output$logout<-renderUI({
    if (USER$Logged == TRUE){
      tags$div(class = "submit",
               tags$a(id="logout2",href = login.page, 
                      "Log Out"
               )
      )
    }
  })
  #######################sidear collapse####################
  addClass(selector = "body", class = "sidebar-collapse")
  
  
  output$body <- renderUI({
    if (USER$Logged == TRUE) {   
######################################tab ui######################################
            tabItems(
        # First tab content
        tabItem(tabName = "Input",box(
          title = "Restore Defaults", status = "primary", solidHeader = TRUE,
          collapsible = TRUE,actionButton("RestoreBig","Restore Defaults Big3"),actionButton("RestoreJATO","Restore Defaults JATO"),actionButton("Restoresuper","Restore Original Master Dictionary"),
          tags$hr(),fileInput("RestoreFile", "Choose Restore File for the System",
                    multiple = FALSE
          ),shinyDirButton("directory", "Folder select", "Please select a folder"),actionButton("RestoreGo","Restore"),tags$hr(),h5(tags$b("Delete Files")),shinyFilesButton("file", "File select", "Please select a file", multiple = FALSE),actionButton("delete", "Delete Files") ,width = "100%",collapsed = FALSE),dataTableOutput("contents"),verbatimTextOutput("new")),
        tabItem(tabName = "Drag", actionButton("add", "Add Bucket"),actionButton("remove", "Remove Bucket"),tags$hr(),uiOutput("new3"),uiOutput("new2"),tags$hr(),tags$hr(),uiOutput("new1"),tableOutput("order1"),verbatimTextOutput("order2")  )
        ,
        tabItem(tabName = "Config",actionButton("Refresh","Refresh"),  tags$hr(),fluidRow(box(
          title = "Data Configuration",width=6,background = "teal", solidHeader = TRUE,
          collapsible = TRUE,selectInput("directory_raw","RAW Folder",choices=list.dirs("./Datagroups/RAW", recursive = FALSE)),uiOutput("fileselection"),uiOutput("versionselection"),actionButton("new2","Set"),actionButton("showtable","GO"))
        ,box(
          title = "Dictionary", width = 6, solidHeader = TRUE,background = "olive",
         disabled(actionButton("load_dict","Configure Dictionary")), disabled(actionButton("Update_super","Update Master Dictionary")),disabled(actionButton("Master_table","Create Master Table")),collapsible = TRUE
        )),uiOutput("data_table") ), tabItem(tabName = "widgets",box(
          title = "Cleaning Methodology", status = "primary", solidHeader = TRUE,
          collapsible = TRUE,tags$iframe(style="height:400px; width:100%; scrolling=yes", 
                                                                             src="JATO-BIG3 Raw Data Cleaning Logic.pdf"),width="100%"
                                             
        ),
        box(
          title = "Questions and Answers", status = "primary", solidHeader = TRUE,
          collapsible = TRUE,dataTableOutput("ques_answ"),width="100%"
                                             
        )) )} else {
      login
    }
  })
  output$ques_answ<-renderDataTable({
    datatable(QA)
  })
  
  ##########################js for data group tab###################
  
  observe({
    if (is.null(input$destm_order) || input$destm_order == "") {
      shinyjs::disable("Save1")
    } else {
      shinyjs::enable("Save1")
    }
  })
  observe({
    if (is.null(input$dest_order) || input$dest_order == "") {
      shinyjs::disable("Save")
    } else {
      shinyjs::enable("Save")
    }
  })
  data_super<-reactiveValues()
 #########################################update Super######################## 
  observeEvent(input$Update_super,{
    file.remove("./Mapping/config_superset/Super_dict.xlsx")
    
    body<-fread("./Mapping/config_ver/body_type_dict_temp.csv",header=TRUE)
    cab<-fread("./Mapping/config_ver/cab_type_dict_temp.csv",header=TRUE)
    powert<-fread("./Mapping/config_ver/power_dict_temp.csv",header=TRUE)
    drivet<-fread("./Mapping/config_ver/drive_dict_temp.csv",header=TRUE)
    fuelt<-fread("./Mapping/config_ver/fuel_type_dict_temp.csv",header=TRUE)
    transt<-fread("./Mapping/config_ver/transmission_dict_temp.csv",header=TRUE)
    jato<-fread("./Mapping/config_ver/jato_family_dict_temp.csv",header=TRUE)
    body<-body[body$cleaned_body_type!="dummy",]
    cab<-cab[cab$cleaned_cab_type!="dummy",]
    powert<-powert[powert$cleaned_powertrain!="dummy",]
    drivet<-drivet[drivet$cleaned_driven_wheel!="dummy",]
    fuelt<-fuelt[fuelt$cleaned_fuel_type!="dummy",]
    transt<-transt[transt$cleaned_transmission!="dummy",]
    jato<-jato[jato$cleaned_brand!="dummy",]
    big3_family<-fread("./Mapping/config_ver/big3_family_dict_temp.csv",header=TRUE)
    comp_flag<-fread("./Mapping/config_ver/comp_type_dict_temp.csv",header=TRUE)
    big3_family<-big3_family[big3_family$cleaned_brand!="dummy",]
    comp_flag<-comp_flag[comp_flag$cleaned_brand!="dummy",]
    ########################################################################################################
      body_index<-fread("./Mapping/config_ver/body_type_dict_index_temp.csv",header=TRUE)
    cab_index<-fread("./Mapping/config_ver/cab_type_dict_index_temp.csv",header=TRUE)
    power_index<-fread("./Mapping/config_ver/power_type_dict_index_temp.csv",header=TRUE)
    manf_index<-fread("./Mapping/config_ver/manf_dict_index_temp.csv",header=TRUE)
    model_index<-fread("./Mapping/config_ver/model_dict_index_temp.csv",header=TRUE)
     fuel_index<-fread("./Mapping/config_ver/fuel_type_dict_index_temp.csv",header=TRUE)
    brand_index<-fread("./Mapping/config_ver/brand_dict_index_temp.csv",header=TRUE)
    country_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="country")
     family_index<-fread("./Mapping/config_ver/family_dict_index_temp.csv",header=TRUE)
     comp_index<-fread("./Mapping/config_ver/comp_dict_index_temp.csv",header=TRUE)
    source_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="source")
     file.remove("./Mapping/config_superset/index/Super_dict_index.xls")
    ########################################################################################################
    write.xlsx(as.data.frame(body),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "Body_type",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(cab),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "cab_type",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(fuelt),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "Fuel",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(jato),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "JATO_FAMILY",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(powert),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "Powertrain",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(transt),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "Transmission",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(drivet),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "Driven_wheel",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(comp_flag),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "Comp_Flag",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(big3_family),"./Mapping/config_superset/Super_dict.xlsx",sheetName = "BIG3_FAMILY",row.names = FALSE,append = TRUE)
    ##################################################################################################################
    write.xlsx(as.data.frame(body_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "Body_type",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(cab_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "cab_type",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(fuel_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "Fuel",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(country_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "country",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(power_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "Powertrain",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(model_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "model",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(brand_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "brand",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(comp_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "comp",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(manf_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "Manufacturer",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(source_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "source",row.names = FALSE,append = TRUE)
    write.xlsx(as.data.frame(family_index),"./Mapping/config_superset/Index/Super_dict_index.xls",sheetName = "family",row.names = FALSE,append = TRUE)
    
     shinyalert("Success","Successfuly updated!", type = "success")
     })
  ############################################################################
  ###################################################################################
#####################Refresh#####################################################
  observeEvent(input$Refresh,{
    session$reload()
  })
###################Code for Dictionary###############################################  
  observeEvent(input$load_dict,{
   
    rawfile<-reactive({
      rawfile<-fread(paste0(input$directory_raw,"/",input$fileselect),header=TRUE)
    })
    
    body_type<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="Body_type")
    cab_type<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="cab_type")
    fuel<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="Fuel")
    comp_flag<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="Comp_Flag")
    # manf<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="Manufacturer")
    JATO_family<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="JATO_FAMILY")
    Big3_family<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="BIG3_FAMILY")
    # Common_family<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="COMMON_FAMILY")
    powertrain<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="Powertrain")
    transmission<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="Transmission")
    driven<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="Driven_wheel")
    
    enable("Update_super")
    
        body_type_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="Body_type")
    cab_type_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="cab_type")
    fuel_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="Fuel")
    comp_flag_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="comp")
     manf<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="Manufacturer")
    family_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="family")
    brand_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="brand")
    # Common_family<-read_excel("./Mapping/config_superset/Super_dict.xlsx",sheet="COMMON_FAMILY")
      
      model_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="model")
      power_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="Powertrain")
    # df_data_reactive$body_type<-body_type
    # df_data_reactive$cab_type<-cab_type
    # df_data_reactive$fuel<-fuel
    # df_data_reactive$comp_flag<-comp_flag
    
    if(grepl("Big3", input$directory_raw,fixed = TRUE)){
      
      #Big3 Comparison
      
      
      file_for_dict1<-rawfile()
      file_for_dict1<-file_for_dict1[file_for_dict1$Filename==input$versionselect,]
      file_for_dict1$source<-"BIG3"
      #Comp flag
      file_for_dict_comp<-file_for_dict1[,c("Country","Brand","Model","Comp flag")]
      file_for_dict_big<-file_for_dict1[,c("Brand","Model","source","Country")]
     
      Big3_family_1<-Big3_family[,c("Brand","Model","source","Country")]
    
      comp<-comp_flag[,c("Country","Brand","Model","Comp flag")]
      new_dict_comp=setdiff(unique(file_for_dict_comp),unique(comp))
      new_dict_big<-setdiff(unique(file_for_dict_big),unique(Big3_family_1))
      
      if(nrow(new_dict_comp)>0){
        new_dict_comp<-as.data.frame( new_dict_comp)
        new_dict_comp$second<-"dummy"
        new_dict_comp$third<-"dummy"
        new_dict_comp$fourth<-"dummy"
        
       
      }else{
        new_dict_comp<-""
        new_dict_comp<-as.data.frame(new_dict_comp)
        new_dict_comp$first<-""
        new_dict_comp$fifth<-""
        new_dict_comp$sixth<-""
        new_dict_comp$second<-""
        new_dict_comp$third<-""
        new_dict_comp$fourth<-""
       
      }   
      
      ####################################################################
      if(nrow(new_dict_big)>0){
        new_dict_big<-as.data.frame( new_dict_big)
        new_dict_big$second<-"dummy"
        new_dict_big$third<-"dummy"
        new_dict_big$fourth<-"dummy"
        new_dict_big$seventh<-"dummy"
        
        colnames(new_dict_big)<-colnames(Big3_family)
        new_dict_big$source<-"BIG3"
      }else{
        new_dict_big<-""
        new_dict_big<-as.data.frame(new_dict_big)
        new_dict_big$first<-""
        new_dict_big$fifth<-""
        new_dict_big$sixth<-""
        new_dict_big$second<-""
        new_dict_big$third<-""
        new_dict_big$fourth<-""
        new_dict_big$seventh<-""
        colnames(new_dict_big)<-colnames(Big3_family)
        new_dict_big$source<-"BIG3"
      }   
      #######################################################################
      
      
      colnames(new_dict_comp)<-colnames(comp_flag)
      df_comp=callModule(editableDT,"comp_type",data=reactive(new_dict_comp),inputwidth=reactive(170))
      df_big3=callModule(editableDT,"big3_family_type",data=reactive(new_dict_big),inputwidth=reactive(170))  
      # df_data_reactive$df_comp<-df_comp()
      observeEvent(input$new14,{
        comp1<-rbind(comp_flag,df_comp()[,1:7])
    
        fwrite(comp1,"./Mapping/config_ver/comp_type_dict_temp.csv",row.names = FALSE)
        comp1<-comp1[comp1$cleaned_brand!="dummy",]
         data_super$comp1<-comp1
         ############################################################################################################# 
        new_dict_comp_index=setdiff(unique(comp1$cleaned_comp_flag),comp_flag_index$competitor_flag)
        
      if(length(new_dict_comp_index)>0){
        new_dict_comp_index<-as.data.frame(new_dict_comp_index)
        new_dict_comp_index$cf_id<-max(comp_flag_index$cf_id)+as.integer(rownames(new_dict_comp_index))
        new_dict_comp_index<-new_dict_comp_index[,c(2,1)]
      
      }else{
        new_dict_comp_index<-""
        new_dict_comp_index<-as.data.frame(new_dict_comp_index)
        new_dict_comp_index$third<-""
        
      }    
      colnames(new_dict_comp_index)<-colnames(comp_flag_index)
      comp_index1<-rbind(comp_flag_index,new_dict_comp_index)
      fwrite(comp_index1,"./Mapping/config_ver/comp_dict_index_temp.csv",row.names = FALSE)
########################################################################################################
         shinyalert("Success","Successfuly updated!", type = "success")
        
        # saveWorkbook(wb, './Mapping/config_superset/Super_dict.xlsx', overwrite = T)
        })
      observeEvent(input$new16,{
        big3_familu<-rbind(Big3_family,df_big3())
        
        fwrite(big3_familu,"./Mapping/config_ver/big3_family_dict_temp.csv",row.names = FALSE)
        big3_f<-big3_familu[big3_familu$cleaned_brand!="dummy",]
        data_super$big3_f<-big3_f
        shinyalert("Success","Successfuly updated!", type = "success")
        
      })
      output$exdiff3<-renderDiffr({
        
        file1 = tempfile()
        fwrite(comp,file1)
        file2 = tempfile()
        fwrite((unique(file_for_dict_comp)),file2)
        
        diffr(file1,file2,before = "Comp Flag Dictionary",after="Comp Flag Current",width="50px")
        
      })
      output$exdiff5<-renderDiffr({
        
        file1 = tempfile()
        m<-as.data.frame(Big3_family_1)
        write.table(m[order(m$Brand,m$Model),],file1)
        file2 = tempfile()
        t<-unique(file_for_dict_big)
        write.table(t[
          order(t$Brand,t$Model),
          ],file2)
        
        diffr(file1,file2,before = "Big3 Family Dictionary",after="Big3 Family Current",width="50px")
        
      })
      
      
      
      
      
      
      
      
      
    }else if(grepl("JATO", input$directory_raw,fixed = TRUE)){
      
      ##############################################JATO COMPARISON#######################
      
      file_for_dict<-rawfile()
      file_for_dict$Filename<-as.character(file_for_dict$Filename)
      file_for_dict<-file_for_dict[file_for_dict$Filename==input$versionselect,]
      file_for_dict$source<-"JATO"
      file_for_dict_jato<-file_for_dict[,c("Brand","Model","source","Country")]
      JATO_family_1<-JATO_family[,c("Brand","Model","source","Country")]
      new_dict_jato<-setdiff(unique(file_for_dict_jato),unique(JATO_family_1))
      #######Comparison###############
      #body_type
      new_dict_bt=setdiff(unique(file_for_dict$`Body Type`),unique(body_type$body_type))
      if(length(new_dict_bt)>0){
        new_dict_bt<-as.data.frame(new_dict_bt)
        new_dict_bt$second<-"dummy"
      
      }else{
        new_dict_bt<-""
        new_dict_bt<-as.data.frame(new_dict_bt)
        new_dict_bt$third<-""
        
      }    
      colnames(new_dict_bt)<-colnames(body_type)
      
      #cab_type
      
      new_dict_ct=setdiff(unique(file_for_dict$`Cab Type`),unique(cab_type$cab_type))
      if(length(new_dict_ct)>0){
        new_dict_ct<-as.data.frame(new_dict_ct)
        new_dict_ct$second<-"dummy"
      
      }else{
        new_dict_ct<-""
        new_dict_ct<-as.data.frame(new_dict_ct)
        new_dict_ct$third<-""
      }    
      colnames(new_dict_ct)<-colnames(cab_type)
      
      #fuel
      
      new_dict_fuel=setdiff(unique(file_for_dict$`Fuel Type`),unique(fuel$Fuel))
      if(length(new_dict_fuel)>0){
        new_dict_fuel<-as.data.frame(new_dict_fuel)
        new_dict_fuel$second<-"dummy"
       
      }else{
        new_dict_fuel<-""
        new_dict_fuel<-as.data.frame(new_dict_fuel)
        new_dict_fuel$third<-""
      }    
      colnames(new_dict_fuel)<-colnames(fuel)
      
      #powertrain
      new_dict_power=setdiff(unique(file_for_dict$`Powertrain Type`),unique(powertrain$powertrain))
      if(length(new_dict_power)>0){
        new_dict_power<-as.data.frame(new_dict_power)
        new_dict_power$second<-"dummy"
        
      }else{
        new_dict_power<-""
        new_dict_power<-as.data.frame(new_dict_power)
        new_dict_power$third<-""
        
      }    
      colnames(new_dict_power)<-colnames(powertrain)
      #Transmission
      new_dict_trans=setdiff(unique(file_for_dict$`Transmission Type`),unique(transmission$transmission))
      if(length(new_dict_trans)>0){
        new_dict_tans<-as.data.frame(new_dict_tans)
        new_dict_tans$second<-"dummy"
        
      }else{
        new_dict_trans<-""
        new_dict_trans<-as.data.frame(new_dict_trans)
        new_dict_trans$third<-""
        
      }    
      colnames(new_dict_trans)<-colnames(transmission)
      #Driven wheel
      new_dict_drive=setdiff(unique(file_for_dict$`Driven Wheels`),unique(driven$driven_wheel))
      if(length(new_dict_drive)>0){
        new_dict_drive<-as.data.frame(new_dict_drive)
        new_dict_drive$second<-"dummy"
        
      }else{
        new_dict_drive<-""
        new_dict_drive<-as.data.frame(new_dict_drive)
        new_dict_drive$third<-""
        
      }    
      colnames(new_dict_drive)<-colnames(driven)
      
      
      
      ####################################################################
      if(nrow(new_dict_jato)>0){
        new_dict_jato<-as.data.frame(new_dict_jato)
        new_dict_jato$second<-"dummy"
        new_dict_jato$third<-"dummy"
        new_dict_jato$fourth<-"dummy"
        new_dict_jato$seventh<-"dummy"

        colnames(new_dict_jato)<-colnames(JATO_family)
        new_dict_jato$source<-"JATO"
      }else{
        new_dict_jato<-""
        new_dict_jato<-as.data.frame(new_dict_jato)
        new_dict_jato$first<-""
        new_dict_jato$fifth<-""
        new_dict_jato$sixth<-""
        new_dict_jato$second<-""
        new_dict_jato$third<-""
        new_dict_jato$fourth<-""
        new_dict_jato$seventh<-""
        colnames(new_dict_jato)<-colnames(JATO_family)
        new_dict_jato$source<-""
      }
      #############################editable df calls#####################################################################
      
      df_body=callModule(editableDT,"body_type",data=reactive(new_dict_bt),inputwidth=reactive(170))  
      df_cab=callModule(editableDT,"cab_type",data=reactive(new_dict_ct),inputwidth=reactive(170))  
      df_fuel=callModule(editableDT,"fuel_type",data=reactive(new_dict_fuel),inputwidth=reactive(170)) 
       df_jato=callModule(editableDT,"Jato_family_type",data=reactive(new_dict_jato),inputwidth=reactive(170)) 
       df_powertrain=callModule(editableDT,"powertrain_type",data=reactive(new_dict_power),inputwidth=reactive(170)) 
       df_trans=callModule(editableDT,"trans_type",data=reactive(new_dict_trans),inputwidth=reactive(170)) 
       df_drive=callModule(editableDT,"drive_type",data=reactive(new_dict_drive),inputwidth=reactive(170)) 
     ##############################observeevent for temporary dictionary file######################################################
      
      observeEvent(input$new11,{
        body1<-rbind(body_type,df_body())
        fwrite(body1,"./Mapping/config_ver/body_type_dict_temp.csv",row.names = FALSE)
        body1<-body1[body1$cleaned_body_type!="dummy",]
        data_super$body1<-body1
        
        new_dict_bt_index=setdiff(unique(body1$cleaned_body_type),body_type_index$body_type)
        
      if(length(new_dict_bt_index)>0){
        new_dict_bt_index<-as.data.frame(new_dict_bt_index)
        new_dict_bt_index$bt_id<-max(body_type_index$bt_id)+as.integer(rownames(new_dict_bt_index))
        new_dict_bt_index<-new_dict_bt_index[,c(2,1)]
      
      }else{
        new_dict_bt_index<-""
        new_dict_bt_index<-as.data.frame(new_dict_bt_index)
        new_dict_bt_index$third<-""
        
      }    
      colnames(new_dict_bt_index)<-colnames(body_type_index)
      body_index1<-rbind(body_type_index,new_dict_bt_index)
      fwrite(body_index1,"./Mapping/config_ver/body_type_dict_index_temp.csv",row.names = FALSE)
        
        shinyalert("Success","Successfuly updated!", type = "success")
        })
      observeEvent(input$new12,{
        cab1<-rbind(cab_type,df_cab())
        fwrite(na.omit(cab1),"./Mapping/config_ver/cab_type_dict_temp.csv",row.names = FALSE)
        cab1<-cab1[cab1$cleaned_cab_type!="dummy",]
        data_super$cab1<-cab1    
        
         new_dict_ct_index=setdiff(unique(cab1$cleaned_cab_type),cab_type_index$cab_type)
        
      if(length(new_dict_ct_index)>0){
        new_dict_ct_index<-as.data.frame(new_dict_ct_index)
        new_dict_ct_index$ct_id<-max(cab_type_index$ct_id)+as.integer(rownames(new_dict_ct_index))
        new_dict_ct_index<-new_dict_ct_index[,c(2,1)]
      
      }else{
        new_dict_ct_index<-""
        new_dict_ct_index<-as.data.frame(new_dict_ct_index)
        new_dict_ct_index$third<-""
        
      }    
      colnames(new_dict_ct_index)<-colnames(cab_type_index)
      cab_index1<-rbind(cab_type_index,new_dict_ct_index)
      fwrite(cab_index1,"./Mapping/config_ver/cab_type_dict_index_temp.csv",row.names = FALSE)
        shinyalert("Success","Successfuly updated!", type = "success")
        })
      observeEvent(input$new13,{
        fuel1<-rbind(fuel,df_fuel())
        fwrite(na.omit(fuel1),"./Mapping/config_ver/fuel_type_dict_temp.csv",row.names = FALSE)
        fuel1<-fuel1[fuel1$cleaned_fuel_type!="dummy",]
        data_super$fuel1<-fuel1
         new_dict_fuel_index=setdiff(unique(fuel1$cleaned_fuel_type),fuel_index$fuel_type)
        
      if(length(new_dict_fuel_index)>0){
        new_dict_fuel_index<-as.data.frame(new_dict_fuel_index)
        new_dict_fuel_index$ft_id<-max(fuel_index$ft_id)+as.integer(rownames(new_dict_fuel_index))
        new_dict_fuel_index<-new_dict_fuel_index[,c(2,1)]
      
      }else{
        new_dict_fuel_index<-""
        new_dict_fuel_index<-as.data.frame(new_dict_fuel_index)
        new_dict_fuel_index$third<-""
        
      }    
      colnames(new_dict_fuel_index)<-colnames(fuel_index)
      fuel_index1<-rbind(fuel_index,new_dict_fuel_index)
      fwrite(fuel_index1,"./Mapping/config_ver/fuel_type_dict_index_temp.csv",row.names = FALSE)
        shinyalert("Success","Successfuly updated!", type = "success")
            })
      observeEvent(input$new15,{
        jato_familu<-rbind(JATO_family,df_jato())
        fwrite(na.omit(jato_familu),"./Mapping/config_ver/jato_family_dict_temp.csv",row.names = FALSE)
        jato_familu<-jato_familu[jato_familu$cleaned_brand!="dummy",]
        data_super$jato_familu<-jato_familu
############################################################################################################# 
        new_dict_manf_index=setdiff(unique(jato_familu$cleaned_manufacturer),manf$manufacturer)

      if(length(new_dict_manf_index)>0){
        new_dict_manf_index<-as.data.frame(new_dict_manf_index)
        new_dict_manf_index$mnf_id<-max(manf$mnf_id)+as.integer(rownames(new_dict_manf_index))
        new_dict_manf_index<-new_dict_manf_index[,c(2,1)]

      }else{
        new_dict_manf_index<-""
        new_dict_manf_index<-as.data.frame(new_dict_manf_index)
        new_dict_manf_index$third<-""

      }
      colnames(new_dict_manf_index)<-colnames(manf)
      manf_index1<-rbind(manf,new_dict_manf_index)
      fwrite(manf_index1,"./Mapping/config_ver/manf_dict_index_temp.csv",row.names = FALSE)
########################################################################################################
 ############################################################################################################# 
        new_dict_model_index=setdiff(unique(jato_familu$cleaned_model),model_index$model)
        
      if(length(new_dict_model_index)>0){
        new_dict_model_index<-as.data.frame(new_dict_model_index)
        new_dict_model_index$mdl_id<-max(model_index$mdl_id)+as.integer(rownames(new_dict_model_index))
        new_dict_model_index<-new_dict_model_index[,c(2,1)]
      
      }else{
        new_dict_model_index<-""
        new_dict_model_index<-as.data.frame(new_dict_model_index)
        new_dict_model_index$third<-""
        
      }    
      colnames(new_dict_model_index)<-colnames(model_index)
      model_index1<-rbind(model_index,new_dict_model_index)
      fwrite(model_index1,"./Mapping/config_ver/model_dict_index_temp.csv",row.names = FALSE)
########################################################################################################
############################################################################################################# 
        new_dict_brand_index=setdiff(unique(jato_familu$cleaned_brand),brand_index$brand)
        
      if(length(new_dict_brand_index)>0){
        new_dict_brand_index<-as.data.frame(new_dict_brand_index)
        new_dict_brand_index$brd_id<-max(brand_index$brd_id)+as.integer(rownames(new_dict_brand_index))
        new_dict_brand_index<-new_dict_brand_index[,c(2,1)]
      
      }else{
        new_dict_brand_index<-""
        new_dict_brand_index<-as.data.frame(new_dict_brand_index)
        new_dict_brand_index$third<-""
        
      }    
      colnames(new_dict_brand_index)<-colnames(brand_index)
      brand_index1<-rbind(brand_index,new_dict_brand_index)
      fwrite(brand_index1,"./Mapping/config_ver/brand_dict_index_temp.csv",row.names = FALSE)
########################################################################################################
      ############################################################################################################# 
        new_dict_family_index<-setdiff(unique(jato_familu$cleaned_family),family_index$family)
        
      if(length(new_dict_family_index)>0){
        new_dict_family_index<-as.data.frame(new_dict_family_index)
        new_dict_family_index$brd_id<-max(family_index$brd_id)+as.integer(rownames(new_dict_family_index))
        new_dict_family_index<-new_dict_family_index[,c(2,1)]
      
      }else{
        new_dict_family_index<-""
        new_dict_family_index<-as.data.frame(new_dict_family_index)
        new_dict_family_index$third<-""
        
      }    
      colnames(new_dict_family_index)<-colnames(family_index)
      family_index1<-rbind(family_index,new_dict_family_index)
      fwrite(family_index1,"./Mapping/config_ver/family_dict_index_temp.csv",row.names = FALSE)
########################################################################################################
        
        shinyalert("Success","Successfuly updated!", type = "success")
        })
      observeEvent(input$new17,{
        power<-rbind(powertrain,df_powertrain())
        fwrite(na.omit(power),"./Mapping/config_ver/power_dict_temp.csv",row.names = FALSE)
        power<-power[power$cleaned_powertrain!="dummy",]
        data_super$power<-power
           new_dict_power_index=setdiff(unique(power$cleaned_powertrain),power_index$powertrain)
        
      if(length(new_dict_power_index)>0){
        new_dict_power_index<-as.data.frame(new_dict_power_index)
        new_dict_power_index$ft_id<-max(power_index$pt_id)+as.integer(rownames(new_dict_power_index))
        new_dict_power_index<-new_dict_power_index[,c(2,1)]
      
      }else{
        new_dict_power_index<-""
        new_dict_power_index<-as.data.frame(new_dict_power_index)
        new_dict_power_index$third<-""
        
      }    
      colnames(new_dict_power_index)<-colnames(power_index)
      power_index1<-rbind(power_index,new_dict_power_index)
      fwrite(power_index1,"./Mapping/config_ver/power_type_dict_index_temp.csv",row.names = FALSE)
        
        shinyalert("Success","Successfuly updated!", type = "success")
        })
      observeEvent(input$new18,{
        trans<-rbind(transmission,df_trans())
        fwrite(na.omit(trans),"./Mapping/config_ver/transmission_dict_temp.csv",row.names = FALSE)
        trans<-trans[trans$cleaned_transmission!="dummy",]
        data_super$trans<-trans
        shinyalert("Success","Successfuly updated!", type = "success")
        })
      observeEvent(input$new19,{
        drve<-rbind(driven,df_drive())
        fwrite(na.omit(drve),"./Mapping/config_ver/drive_dict_temp.csv",row.names = FALSE)
        drve<-drve[drve$cleaned_driven_wheel!="dummy",]
        data_super$drve<-drve      
        shinyalert("Success","Successfuly updated!", type = "success")
        })
      ################################## diffr calls################################
      output$exdiff<-renderDiffr({
        
        file1 = tempfile()
        dput(body_type$body_type,file1)
        file2 = tempfile()
       dput(unique(file_for_dict$'Body Type'),file2)
        diffr(file1,file2,before = "Body Type Dictionary",after="Body Type Current")
  
      })
      output$exdiff1<-renderDiffr({
        
        file1 = tempfile()
        dput((cab_type$cab_type),file1)
        file2 = tempfile()
        dput((unique(file_for_dict$'Cab Type')),file2)
        diffr(file1,file2,before = "Cab Type Dictionary",after="Cab Type Current")
      
      })
      output$exdiff2<-renderDiffr({
        
        file1 = tempfile()
       dput(fuel$Fuel,file1)
        file2 = tempfile()
        dput((unique(file_for_dict$'Fuel Type')),file2)
        diffr(file1,file2,before = "Fuel Type Dictionary",after="Fuel Type Current")
        
      })
      output$exdiff4<-renderDiffr({
        
        file1 = tempfile()
        m<-unique(JATO_family_1)
        write.table(m[order(m$Brand,m$Model),],file1)
        file2 = tempfile()
        t<-unique(file_for_dict_jato)
        write.table(t[order(t$Brand,t$Model),] ,file2)
        diffr(file1,file2,before = "JATO FAMILY Dictionary",after="JATO FAMILY Current")
        
      })
      output$exdiff6<-renderDiffr({
        
        file1 = tempfile()
        dput(powertrain$powertrain,file1)
        file2 = tempfile()
        dput(unique(file_for_dict$`Powertrain Type`),file2)
        diffr(file1,file2,before = "Powertrain Type Dictionary",after="Powertrain Type Current")
        
      })
      output$exdiff7<-renderDiffr({
        
        file1 = tempfile()
        dput(transmission$transmission,file1)
        file2 = tempfile()
        dput(unique(file_for_dict$`Transmission Type`),file2)
        diffr(file1,file2,before = "Transmission Type Dictionary",after="Transmission Type Current")
        
      })
      output$exdiff8<-renderDiffr({
      
        file1 = tempfile()
        dput(driven$driven_wheel,file1)
        file2 = tempfile()
        dput(unique(file_for_dict$`Driven Wheels`),file2)
        diffr(file1,file2,before = "Driven Wheel Type Dictionary",after="Driven Wheel Type Current")
        
      })
      ########################################################################################
      
    }
    
   
   
    ###################tabsest Panel call###################
    output$data_table<-renderUI({
      div(id="tabs1",tabsetPanel(
   tabPanel("Body Type",editableDTUI("body_type"), actionButton("new11","Update Dictionary"),tags$hr(),box(
     title = "View Data", 
     width = NULL,
     status = "primary", 
     solidHeader = TRUE,
     collapsible = TRUE,
     div(style = 'overflow-x: scroll',diffrOutput("exdiff")),collapsed = TRUE)),
   tabPanel("Cab Type",editableDTUI("cab_type"), actionButton("new12","Update Dictionary"),tags$hr(),box(
     title = "View Data", 
     width = NULL,
     status = "primary", 
     solidHeader = TRUE,
     collapsible = TRUE,
     div(style = 'overflow-x: scroll',diffrOutput("exdiff1") ),collapsed = TRUE)),
  tabPanel("Fuel",editableDTUI("fuel_type"), actionButton("new13","Update Dictionary"),tags$hr(),box(
    title = "View Data", 
    width = NULL,
    status = "primary", 
    solidHeader = TRUE,
    collapsible = TRUE,
    div(style = 'overflow-x: scroll',diffrOutput("exdiff2") ),collapsed = TRUE)),
  tabPanel("JATO Family",editableDTUI("Jato_family_type"), actionButton("new15","Update Dictionary"),tags$hr(),box(
    title = "View Data", 
    width = NULL,
    status = "primary", 
    solidHeader = TRUE,
    collapsible = TRUE,
    div(style = 'overflow-x: scroll',diffrOutput("exdiff4") ),collapsed = TRUE)),
    tabPanel("Comp Flag",editableDTUI("comp_type"), actionButton("new14","Update Dictionary") ,tags$hr(),box(
      title = "View Data", 
      width = NULL,
      status = "primary", 
      solidHeader = TRUE,
      collapsible = TRUE,
      div(style = 'overflow-x: scroll',diffrOutput("exdiff3")),collapsed = TRUE)),
    # tabPanel("Manufacturer",dataTableOutput("mnf_type") ),
  tabPanel("Powertrain",editableDTUI("powertrain_type"), actionButton("new17","Update Dictionary"),box(
    title = "View Data", 
    width = NULL,
    status = "primary", 
    solidHeader = TRUE,
    collapsible = TRUE,
    div(style = 'overflow-x: scroll',diffrOutput("exdiff6")),collapsed = TRUE)),
  tabPanel("Transmission",editableDTUI("trans_type"), actionButton("new18","Update Dictionary"),box(
    title = "View Data", 
    width = NULL,
    status = "primary", 
    solidHeader = TRUE,
    collapsible = TRUE,
    div(style = 'overflow-x: scroll',diffrOutput("exdiff7")),collapsed = TRUE)),
  tabPanel("Driven wheel",editableDTUI("drive_type"), actionButton("new19","Update Dictionary"),box(
    title = "View Data", 
    width = NULL,
    status = "primary", 
    solidHeader = TRUE,
    collapsible = TRUE,
    div(style = 'overflow-x: scroll',diffrOutput("exdiff8")),collapsed = TRUE)),
  
    tabPanel("Big3 Family",editableDTUI("big3_family_type"), actionButton("new16","Update Dictionary"),tags$hr(),box(
      title = "View Data", 
      width = NULL,
      status = "primary", 
      solidHeader = TRUE,
      collapsible = TRUE,
      div(style = 'overflow-x: scroll',diffrOutput("exdiff5") ),collapsed = TRUE))
  
      )
    )
      
    }
    
    
    
  )
    
 ###########################################################################
   
 
 
    output$big3_family_type<-renderDataTable({
      datatable(Big3_family,editable = TRUE,class = 'cell-border stripe',filter = 'top')
    })

  })
  
  observeEvent(input$showtable,{
      
      rawfile<-reactive({
        rawfile<-fread(paste0(input$directory_raw,"/",input$fileselect),header=TRUE)
        file_for_dict<-rawfile[rawfile$Filename==input$versionselect,] 
        file_for_dict$source<-"JATO"
        file_for_dict[,c("Brand","Model","source","Country")]
          })
      
    
    output$aa<-renderDataTable({
      final_file<-rawfile()


      # final_file
    })
    output$data_table<-renderUI({

     dataTableOutput("aa")
    })
  })
 
  
  output$fileselection<-renderUI({
    selectInput("fileselect","Select File",choices = list.files(input$directory_raw))
  })
  datatable1<-reactiveValues()
  
  observeEvent(input$new2,{
    
    enable("load_dict")
    rawfile<-reactive({
      rawfile<-fread(paste0(input$directory_raw,"/",input$fileselect),header=TRUE)
    })
  output$versionselection<-renderUI({
    
    selectInput("versionselect","Select Version",choices = unique(rawfile()$Filename))
  })
  # datatable1$file<-rawfile()
})
  
###########################call module toggle shiny load dictionary #########  
  observeEvent(input$`body_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
  observeEvent(input$`cab_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
  observeEvent(input$`fuel_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
  observeEvent(input$`Jato_family_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
  observeEvent(input$`comp_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
  observeEvent(input$`powertrain_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
  observeEvent(input$`trans_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
  observeEvent(input$`drive_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
  observeEvent(input$`big3_family_type-editData`,{
    shinyjs::disable("load_dict")
    
  })
 
  
##############################sidebarpanel UI###############################################
  output$sidebarpanel <- renderUI({
    if (USER$Logged == TRUE) {
      div(id="input_user",
        
       
        
         fileInput("myFile", "Upload Files to Server",
                              multiple = TRUE
                              ),
          
              
                    actionButton("button", "Load Server file list"),
                 
                    # Horizontal line ----
                    tags$hr(),
                    sidebarMenu(id = "tabs",selected = "Input",
                      menuItem("Server Table", tabName = "Input", icon =  icon("folder-open", class = NULL, lib = "font-awesome"),selected = TRUE),
                      menuItem("Data Groups", tabName = "Drag", icon =  icon("sitemap", class = NULL, lib = "font-awesome")),
                      menuItem("Configuration", tabName = "Config", icon =  icon("cog", lib = "glyphicon")),
                      menuItem("FAQ", tabName = "widgets", icon =  icon("code", class = NULL, lib = "font-awesome"))
                     
                    ),
         bsTooltip("input_user", "Upload excel format files only (.xls/.xlsx)",
                    "right",trigger = "hover")
                    
        )
         
      
    }
  })
  
  
  
  values<-reactiveValues(a=2)
  
  # load the files using the fileupload widget  
  
  # Restore to the files 
  
  observeEvent(input$RestoreBig,{
    current_folder<-"./Default/Big3/"
    list_of_files <- list.files(current_folder) 
    file.copy(file.path(current_folder,list_of_files),"./Datagroups/RAW/Big3",overwrite = TRUE)
    shinyalert("Success","Successfuly restored!", type = "success")
    
    
  })
  observeEvent(input$Restoresuper,{
    current_folder<-"./Default/Superdict/"
    list_of_files <- list.files(current_folder) 
    file.copy(file.path(current_folder,list_of_files),"./Mapping/config_superset/",overwrite = TRUE)
    shinyalert("Success","Successfuly restored!", type = "success")
    
    current_folder1<-"./Default/Superdict/Index"
    list_of_files1 <- list.files(current_folder1) 
    file.copy(file.path(current_folder1,list_of_files1),"./Mapping/config_superset/Index",overwrite = TRUE)
    
    
  })
  observeEvent(input$RestoreJATO,{
    current_folder1<-"./Default/JATO/"
    list_of_files <- list.files(current_folder1) 
    file.copy(file.path(current_folder1,list_of_files),"./Datagroups/RAW/JATO",overwrite = TRUE)
    shinyalert("Success","Successfuly restored!", type = "success")
  })
  
  observeEvent(input$RestoreGo, {
    inFile <- input$RestoreFile
    
    file.copy(inFile$datapath,paste0(parseDirPath(volumes, input$directory),"/","other_master.csv") ,recursive = FALSE,overwrite = FALSE )
    
    
  })
  
  
  # Delete file for cleaning the system
  
  filet<-reactive({
    parseFilePaths(volumes, input$file)$datapath
  })
  observeEvent(input$delete,{
   t<-filet()
    if(length(t)==0){
    showModal(modalDialog(
      title = "Important message",
     "please choose a file to delete",
      easyClose = TRUE
    ))
    }else{
      showModal(modalDialog(
        title = "Are you Sure?",
        actionButton("delete1","Delete"),
        easyClose = TRUE
      ))
    }
  })
  observeEvent(input$delete1,{
    file.remove(filet())
  })
  
  observeEvent(input$myFile, {
    inFile <- input$myFile
    files<-list.files("./Data/")
    if (is.null(inFile))
      return()
    
    a=regexpr("\\.",inFile$name)
    b=nchar(inFile$name)
    c<-substr(inFile$name,a+1,b)
    file.copy(inFile$datapath, file.path("./Data/", paste0(stri_extract(inFile$name, regex='[^.]*'),str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""),".",c)),recursive = FALSE,overwrite = FALSE )
    
    
  })
  output$new<-renderText({
    print(parseDirPath(volumes, input$directory))
  })
  # Reactive file list  

  
  
  
 
  datavalues_files_server<-reactiveValues()
  
 
  
  # server table output
  
  observeEvent(input$button,{
    
    files2<-reactive({
      
      files<-list.files("./Data/")
      if(length(files)==0)
        return()
      files<-as.data.frame(files)
      colnames(files)<-"Filename"
      files$Filename<-as.character(files$Filename)
      for(i in 1:length(files$Filename)){
        files$timestamp[i]<-as.character(file.info(paste0("./Data/",files$Filename[i]))$ctime)
      }
      files1<-files[order(files$timestamp,decreasing = TRUE),]
      files1
    })
    
    output$contents<-renderDataTable({
      
      datatable(files2(),rownames = FALSE,editable = TRUE,filter = 'top',class = 'cell-border stripe')
    })
    datavalues_files_server$files2<-files2()
  })
  
  # Order Input in the files for the source of all the files in Data groups tab  
  
  output$new1<-renderUI({
    vars <-as.character((datavalues_files_server$files2[[1]]))
    box(
      title = "Files on Server", status = "primary", solidHeader = TRUE,
      collapsible = TRUE,
      orderInput('source', 'Files on Server', item_class = 'primary',items =vars,
                 connect = c('dest','destm',paste0('dest',1:values$a),'source'),width = "100%"),width = "100%"
    )
    
    
  })
  
  # Big3 droppable space    
  
  output$new3<-renderUI({
    box(
      title = "Big3", status = "warning", solidHeader = TRUE,
      collapsible = TRUE, orderInput('dest',"Big3", items = NULL, placeholder = 'Drag items here...', connect = c('dest','destm',paste0('dest',1:values$a),'source'),width = "100%"),actionButton('Save', "Save Raw"),actionButton('clean', "Save Clean"),width = "100%")
  })
  
  # Big3 cleaning procedure
  
  data_clean<-reactiveValues()
  observeEvent(input$clean,{
    rawfile<-reactive({
      fread("./Datagroups/RAW/Big3/Big3_master.csv",header=TRUE)
    })
    showModal(modalDialog(
      title = "Clean Data",
      selectInput("big3_clean","Choose File Version",choices =unique(rawfile()$Filename),width = "100%"),
      actionButton("merge_big3","Merge Files"),downloadButton("Downloadbutton_clean_Big3", label = "Download"),
      easyClose = TRUE
    ))
  })
  
  #Big3 merge files
  
  observeEvent(input$merge_big3,{
    big3_family<-fread("./Mapping/config_ver/big3_family_dict_temp.csv",header=TRUE)
    comp_flag<-fread("./Mapping/config_ver/comp_type_dict_temp.csv",header=TRUE)
    big3_family<-big3_family[big3_family$cleaned_brand!="dummy",]
    comp_flag<-comp_flag[comp_flag$cleaned_brand!="dummy",]
    comp_flag<-comp_flag[,c("Country","Brand","Model","Comp flag","cleaned_comp_flag")]
    rawfile<-fread("./Datagroups/RAW/Big3/Big3_master.csv",header=TRUE)
    file_for_dict<-rawfile[rawfile$Filename==input$big3_clean,] 
    big3_clean<-merge(file_for_dict,comp_flag,by=c("Country","Brand","Model","Comp flag"))
    big3_clean<-merge(big3_clean,big3_family,by=c("Country","Brand","Model"))
    big3_clean<-big3_clean[,c("Category","Sub category","Country","cleaned_brand","cleaned_model","cleaned_family","cleaned_manufacturer","cleaned_comp_flag","Date","Score")]
    colnames(big3_clean)<-c("Category","Sub category","Country","brand","model","family","manufacturer","competitor_flag","Date","Score")
    fwrite(big3_clean,paste("./Datagroups/CLEAN/Big3/Big3_clean",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = ""))
    data_clean$big3_clean<-big3_clean
    enable("Master_table")
    shinyalert("Success","Successfuly merged!", type = "success")
  })
  
  
  output$Downloadbutton_clean_Big3 <- downloadHandler(
    filename = function() {
      paste("Big3_clean",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = "")
    },
    content = function(file) {
      fwrite(isolate(data_clean$big3_clean), file, row.names = FALSE)
      
    })
  
  
  
  
  # Jato droppable space
  
  output$new2<-renderUI({
    box(
      title = "JATO", status = "warning", solidHeader = TRUE,
      collapsible = TRUE,orderInput('destm', 'JATO', items = NULL,placeholder = 'Drag items here...', connect = c('dest','destm',paste0('dest',1:values$a),'source'),width = "100%"),actionButton('Save1', "Save Raw"),actionButton('clean1', "Save Clean"),width = "100%")
  })
  
  # JATO cleaning Process
  
  observeEvent(input$clean1,{
    rawfile<-reactive({
      fread("./Datagroups/RAW/JATO/JATO_master.csv",header=TRUE)
    })
    showModal(modalDialog(
      title = "Clean Data",
      selectInput("JATO_clean","Choose File Version",choices =unique(rawfile()$Filename),width = "100%"),
      actionButton("merge_JATO","Merge Files"),downloadButton("Downloadbutton_clean_jat", label = "Download"),
      easyClose = TRUE
    ))
  })
  observeEvent(input$merge_JATO,{
          
        body<-fread("./Mapping/config_ver/body_type_dict_temp.csv",header=TRUE)
        cab<-fread("./Mapping/config_ver/cab_type_dict_temp.csv",header=TRUE)
        powert<-fread("./Mapping/config_ver/power_dict_temp.csv",header=TRUE)
        drivet<-fread("./Mapping/config_ver/drive_dict_temp.csv",header=TRUE)
        fuelt<-fread("./Mapping/config_ver/fuel_type_dict_temp.csv",header=TRUE)
        transt<-fread("./Mapping/config_ver/transmission_dict_temp.csv",header=TRUE)
        jato<-fread("./Mapping/config_ver/jato_family_dict_temp.csv",header=TRUE)
        body<-body[body$cleaned_body_type!="dummy",]
        cab<-cab[cab$cleaned_cab_type!="dummy",]
        powert<-powert[powert$cleaned_powertrain!="dummy",]
        drivet<-drivet[drivet$cleaned_driven_wheel!="dummy",]
        fuelt<-fuelt[fuelt$cleaned_fuel_type!="dummy",]
        transt<-transt[transt$cleaned_transmission!="dummy",]
        jato<-jato[jato$cleaned_brand!="dummy",]
        rawfile<-fread("./Datagroups/RAW/JATO/JATO_master.csv",header=TRUE)
        file_for_dict<-rawfile[rawfile$Filename==input$JATO_clean,]
        JATO_clean<-merge(file_for_dict,body,by.x="Body Type",by.y="body_type")
        JATO_clean<-merge(JATO_clean,cab,by.x="Cab Type",by.y="cab_type")
        JATO_clean<-merge(JATO_clean,powert,by.x="Powertrain Type",by.y="powertrain")
        JATO_clean<-merge(JATO_clean,drivet,by.x="Driven Wheels",by.y="driven_wheel")
        JATO_clean<-merge(JATO_clean,fuelt,by.x="Fuel Type",by.y="Fuel")
        JATO_clean<-merge(JATO_clean,transt,by.x="Transmission Type",by.y="transmission")
        JATO_clean<-merge(JATO_clean,jato,by=c("Country","Brand","Model"))
        JATO_clean<-JATO_clean[,c("Country","cleaned_family","cleaned_manufacturer","cleaned_brand","cleaned_model","cleaned_body_type"
        ,"cleaned_cab_type","cleaned_powertrain","cleaned_driven_wheel","cleaned_fuel_type","cleaned_transmission","Unique Identity","Version Name(MMix)","Liters","Year Month Date","Volume")]
        colnames(JATO_clean)<-c("Country","family","manufacturer","brand","model","body_type"
                                ,"cab_type","powertrain","driven_wheel","fuel_type","transmission","Unique Identity","Version Name","Liters","Date","Volume")
        fwrite(JATO_clean,paste("./Datagroups/CLEAN/JATO/JATO_clean",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = ""))
        
         data_clean$jato<-JATO_clean
          enable("Master_table")
         shinyalert("Success","Successfuly merged!", type = "success")
        })
  
  # Generate Master Table
  
  observeEvent(input$Master_table,{
          body_index<-fread("./Mapping/config_ver/body_type_dict_index_temp.csv",header=TRUE)
    cab_index<-fread("./Mapping/config_ver/cab_type_dict_index_temp.csv",header=TRUE)
    power_index<-fread("./Mapping/config_ver/power_type_dict_index_temp.csv",header=TRUE)
    manf_index<-fread("./Mapping/config_ver/manf_dict_index_temp.csv",header=TRUE)
    model_index<-fread("./Mapping/config_ver/model_dict_index_temp.csv",header=TRUE)
     fuel_index<-fread("./Mapping/config_ver/fuel_type_dict_index_temp.csv",header=TRUE)
    brand_index<-fread("./Mapping/config_ver/brand_dict_index_temp.csv",header=TRUE)
    country_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="country")
     family_index<-fread("./Mapping/config_ver/family_dict_index_temp.csv",header=TRUE)
     comp_index<-fread("./Mapping/config_ver/comp_dict_index_temp.csv",header=TRUE)
    source_index<-read_excel("./Mapping/config_superset/Index/Super_dict_index.xls",sheet="source")
    jato_data<-isolate(data_clean$jato)
    big3<-isolate(data_clean$big3_clean)
    jato_data<-jato_data[,c("Country","family","manufacturer","brand","model","body_type"
                                ,"cab_type","powertrain","fuel_type","Liters")]
    
    big3<-big3[,c("Country","family","manufacturer","brand","model","competitor_flag")]
    big3<-unique(big3)
    jato_data<-unique(jato_data)
    model_index$model<-as.character(model_index$model)
  
    
    big_jato<-merge(jato_data,big3,by=c("Country","family","manufacturer","brand","model"),all=TRUE)
    big_jato<-merge(big_jato,brand_index,by="brand",all.x=TRUE)
    big_jato<-merge(big_jato,model_index,by="model",all.x=TRUE)
    big_jato<-merge(big_jato,country_index,by="Country",all.x=TRUE)
    big_jato<-merge(big_jato,family_index,by="family",all.x=TRUE)

    big_jato<-merge(big_jato,body_type_index,by="body_type",all.x=TRUE)
    big_jato<-merge(big_jato,cab_index,by="cab_type",all.x=TRUE)
    big_jato<-merge(big_jato,power_index,by="powertrain",all.x=TRUE)
    big_jato<-merge(big_jato,fuel_index,by="fuel_type",all.x=TRUE)
    big_jato<-merge(big_jato,comp_index,by="competitor_flag",all.x=TRUE)
    big_jato<-merge(big_jato,manf_index,by="manufacturer",all.x=TRUE)
    
    # 
    big_jato1<-big_jato[,c("brd_id","mdl_id","cntr_id","mnf_id","fml_id","bt_id","ct_id","pt_id","ft_id","cf_id","Liters")]
    data_clean$big_jato<-big_jato
    data_clean$big_jato1<-big_jato1
    
    fwrite(big_jato,paste("./Mapping/master/master_table_total",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = ""))
    fwrite(big_jato1,paste("./Mapping/master/master_table_indexed",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = ""))
   showModal(modalDialog(
      title = "Master  Table",
      
      downloadButton("Downloadbutton_master_total", label = "Download Master Total"),downloadButton("Downloadbutton_master_indexed", label = "Download Master Indexed"),
      easyClose = TRUE
    ))
   
       })
  output$Downloadbutton_master_total <- downloadHandler(
    filename = function() {
      paste("Master_Total",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = "")
    },
    content = function(file) {
      fwrite(isolate( data_clean$big_jato), file, row.names = FALSE)
      
    })
  output$Downloadbutton_master_indexed <- downloadHandler(
    filename = function() {
      paste("Master_Indexed",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = "")
    },
    content = function(file) {
      fwrite(isolate( data_clean$big_jato1), file, row.names = FALSE)
      
    })
  
  output$Downloadbutton_clean_jat <- downloadHandler(
    filename = function() {
      paste("JATO_clean",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = "")
    },
    content = function(file) {
      fwrite(isolate(data_clean$jato), file, row.names = FALSE)
      
    })
  
  
  
  #  Dynamic bucket codes
  
  observeEvent(input$add, {
    insertUI(
      selector = "#add",
      where = "beforeBegin",
      ui = div(id=paste0("contains",values$a),box(
        title = paste0('Other Bucket ',values$a), status = "warning", solidHeader = TRUE,
        collapsible = TRUE, textInput(paste0('bucket',values$a),"Bucket Name") ,orderInput(paste0('dest',values$a), paste0('Other Bucket ',values$a), item_class = 'primary',items = NULL,placeholder = 'Drag items here...',
                                        connect = c('dest',paste0('dest',1:(values$a+100)),'destm','source'),width = "100%"),actionButton(paste0('create',values$a), "Create Bucket"),actionButton(paste0('save',values$a), "Save Raw"),actionButton(paste0('clean',values$a), "Save clean"),width="100%")
        
      ))
    values$a<-values$a+1
  })
  
  # Remove dynamic buckets
  
  observeEvent(input$remove, {
    removeUI(
      selector = paste0('#','box',values$a-1)
    )
    removeUI(
      selector =paste0('#','contains',values$a-1)         
    )
    
    values$a<-values$a-1
  })
  
  output$order1<-renderTable({
  # datavalues$data

  })  
  
  output$order2<-renderPrint({
    print(files4())
  }) 
  files3<-reactive({
    input$dest_order
  })
  files4<-reactive({
    input$destm_order
  })
 # datavalues <- reactiveValues()

  # Big3 data grouping
  
  observeEvent(input$Save,{
    big3<-fread("./Datagroups/RAW/Big3/Big3_master.csv",header=TRUE)
    for(i in 1:length(files3())){
      t<-read_excel(paste0("./Data/",files3()[i]),sheet=1,col_types = "text")
      t$Date<-convertToDate(as.character(t$Date), origin = "1900-01-01")
      t$Filename<-files3()[i]
      big3=rbind.fill(big3,t)
    }
    big3<-big3[big3$Country=="USA" | big3$Country=="PRC",]
    big3<-big3 %>%mutate_all(toupper)
    columns1<-c("FUNNEL","OAO","IMAGE","MSRPVA","SHARE","TPVA","SOV")
    big3<-big3 %>% filter(Category %in% columns1)
      
    colnames(big3)[colnames(big3)=="Corporate"] <- "Brand"
    fwrite(big3,"./Datagroups/RAW/Big3/Big3_master.csv",row.names = FALSE)
    
    showModal(modalDialog(
      title = "Download Raw Big3",
      downloadButton("downloadData", "Download")
    ))
    output$downloadData <- downloadHandler(
      filename = function() {
        paste("Big3",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = "")
      },
      content = function(file) {
        fwrite(big3, file, row.names = FALSE)
      }
    )
    
    # datavalues$data<-big3
    })
 
  # JATO data grouping
  
  observeEvent(input$Save1,{
     JATO<-fread("./Datagroups/RAW/JATO/JATO_master.csv",header=TRUE)
    for(i in 1:length(files4())){
      for(j in 1:length(excel_sheets(paste0("./Data/",files4()[i])))){
      t<-read_excel(paste0("./Data/",files4()[i]),sheet=j,col_types = "text")
      t<-t %>% separate(`Make:Model`, c("Make_latest", "Model"), ":")
      t$`Year Month Date`<-convertToDate(as.character(t$`Year Month Date`), origin = "1900-01-01")
      colnames(t)[colnames(t)=="Make"] <- "Brand"
      t$Filename<-files4()[i]
      JATO=rbind.fill(JATO,t)
      }
    }
    # for(i in 1:length(files4())){
    #   t<-read_excel(paste0("./Data/",files4()[i]),sheet=1,col_types = "text")
    #   # t$Date<-convertToDate(as.character(t$Date), origin = "1900-01-01")
    #   t$Filename<-files4()[i]
    #   JATO=rbind.fill( JATO,t)
    # }
    
    JATO<-JATO[JATO$Filename!="XXXXXX",]
    # 
    # colnames(JATO)[colnames(JATO)=="Make"] <- "Brand"
    JATO <- within(JATO, Country[Country=="US"] <- "USA")
    JATO <- within(JATO, Country[Country=="China"] <- "PRC")
    
        
    fwrite(JATO,"./Datagroups/RAW/JATO/JATO_master.csv",row.names = FALSE)
    
    showModal(modalDialog(
      title = "Download Raw JATO",
      downloadButton("downloadData1", "Download")
    ))
    output$downloadData1 <- downloadHandler(
      filename = function() {
        paste("JATO",str_replace_all(str_replace_all(format(Sys.time()), pattern=" ", repl=""), pattern=":", repl=""), ".csv", sep = "")
      },
      content = function(file) {
        fwrite(JATO, file, row.names = FALSE)
      }
    )
    

  })
  
 
  observeEvent(input$Login, { 
    if (USER$Logged == TRUE){
      updateTabItems(session, "tabs", "Input")
      removeClass(selector = "body", class = "sidebar-collapse")
    }
  
  })


}

shinyApp(ui, server)



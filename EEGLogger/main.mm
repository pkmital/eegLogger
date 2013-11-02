
// Data will be saved to file : EEGLogger.csv

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#include "edk.h"
#include "edkErrorCode.h"
#include "EmoStateDLL.h"
#include "ofxOsc.h"
#endif 

#define HOSTNAME "127.0.0.1"
#define PORT 12345

ofxOscSender sender;

EE_DataChannel_t targetChannelList[] = {
    ED_COUNTER,
    ED_AF3, ED_F7, ED_F3, ED_FC5, ED_T7, 
    ED_P7, ED_O1, ED_O2, ED_P8, ED_T8, 
    ED_FC6, ED_F4, ED_F8, ED_AF4, ED_GYROX, ED_GYROY, ED_TIMESTAMP, 
    ED_FUNC_ID, ED_FUNC_VALUE, ED_MARKER, ED_SYNC_SIGNAL
};

const char header[] = "COUNTER,AF3,F7,F3, FC5, T7, P7, O1, O2,P8" 
", T8, FC6, F4,F8, AF4,GYROX, GYROY, TIMESTAMP, "   
"FUNC_ID, FUNC_VALUE, MARKER, SYNC_SIGNAL,";

const char *headerStr = "COUNTER,AF3,F7,F3, FC5, T7, P7, O1, O2,P8, T8, FC6, F4,F8, AF4,GYROX, GYROY, TIMESTAMP, FUNC_ID, FUNC_VALUE,MARKER, SYNC_SIGNAL,";
const char *newLine = "\n";
const char *comma = ",";

void saveStr(NSFileHandle *, NSMutableData *, const char*);
void saveDoubleVal(NSFileHandle *, NSMutableData *, const double);


int main (int argc, const char * argv[])
{

    sender.setup(HOSTNAME, PORT);
    
    @autoreleasepool {
        
        EmoEngineEventHandle eEvent			= EE_EmoEngineEventCreate();
        EmoStateHandle eState				= EE_EmoStateCreate();
        unsigned int userID					= 0;
        const unsigned short composerPort	= 1726;
        float secs							= 1;
        unsigned int datarate				= 0;
        bool readytocollect					= false;
        int option							= 0;
        int state                           = 0;
        
        bool connected = FALSE;
        
        if(EE_EngineConnect()==EDK_OK)
        {
            connected = TRUE;
            NSLog(@"Start reveiving EEG data !" );
        }
        else
        {
            connected = FALSE;
            NSLog(@"Cannot connect to EmoEngine !");
        }
        
        if(connected)
        {
            NSString* fileName = @"EEGLogger.csv";
            NSString* createFile = @"";
            [createFile writeToFile:fileName atomically:YES encoding:NSUnicodeStringEncoding error:nil];
            NSFileHandle *file;
            NSMutableData *data;
            file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
            saveStr(file, data, headerStr);
            saveStr(file, data, newLine);                        
            
            DataHandle hData = EE_DataCreate();
            EE_DataSetBufferSizeInSec(secs);
            
            NSLog(@"Buffer size in secs : %f",secs);
            
            while (TRUE) 
            {
                state = EE_EngineGetNextEvent(eEvent);
                
                if (state == EDK_OK) 
                {
                    
                    EE_Event_t eventType = EE_EmoEngineEventGetType(eEvent);
                    EE_EmoEngineEventGetUserId(eEvent, &userID);
                    
                    // Log the EmoState if it has been updated
                    if (eventType == EE_UserAdded) 
                    {
                        NSLog(@"User Added");
                        EE_DataAcquisitionEnable(userID,TRUE);
                        readytocollect = TRUE;
                    }
                }
                
                if (readytocollect) 
                {                    
                    EE_DataUpdateHandle(0, hData);
                    
                    unsigned int nSamplesTaken=0;
                    EE_DataGetNumberOfSample(hData,&nSamplesTaken);
                    
                    NSLog(@"Updated : %i",nSamplesTaken); 
                    if (nSamplesTaken != 0) 
                    {
                        
                        double* ddata = new double[nSamplesTaken];
                        for (int sampleIdx=0 ; sampleIdx<(int)nSamplesTaken ; ++sampleIdx) {
                            
                            ofxOscMessage m;
                            m.setAddress("/eeg");
                            
                            for (int i = 0 ; i<sizeof(targetChannelList)/sizeof(EE_DataChannel_t) ; i++) {
                                
                                EE_DataGet(hData, targetChannelList[i], ddata, nSamplesTaken);                                
                                //saveDoubleVal(file, data, ddata[sampleIdx]);
                                //saveStr(file, data, comma);
                                
                                m.addFloatArg((float)ddata[sampleIdx]);
                            }	
                            
                            sender.sendMessage(m);
                            
                            //saveStr(file, data, newLine );
                        }
                        delete[] ddata;
                    }
                    
                }
            }
        }
        
        EE_EngineDisconnect();
        EE_EmoStateFree(eState);
        EE_EmoEngineEventFree(eEvent);
                
    }
    return 0;
}

void saveStr(NSFileHandle *file, NSMutableData *data, const char* str)
{
    [file seekToEndOfFile];
    data = [NSMutableData dataWithBytes:str length:strlen(str)];
    [file writeData:data];
}

void saveDoubleVal(NSFileHandle *file, NSMutableData *data, const double val)
{
    NSString* str = [NSString stringWithFormat:@"%f",val];
    const char* myValStr = (const char*)[str UTF8String];
    saveStr(file,data,myValStr);          
}


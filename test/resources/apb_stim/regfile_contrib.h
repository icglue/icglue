#ifndef __REGFILE_CONTRIB_H__
#define __REGFILE_CONTRIB_H__

#include <stdint.h>

typedef uint32_t rf_data_t;
typedef uint32_t rf_addr_t;

class regfile_dev {
    public:
        virtual rf_data_t rfdev_read (rf_addr_t addr)                                                          = 0;
        virtual void      rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask) = 0;
        virtual void      rfdev_write_sequence (unsigned int length, rf_addr_t addr[], rf_data_t value[], rf_data_t mask[], rf_data_t unused_mask[]);
        virtual ~regfile_dev();
};

class regfile_dev_simple : public regfile_dev {
    public:
        virtual void rfdev_write_simple (rf_addr_t addr, rf_data_t value) = 0;
        virtual void rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask);
        virtual ~regfile_dev_simple();
};

class regfile_dev_subword : public regfile_dev {
    public:
        virtual void rfdev_write_subword (rf_addr_t addr, rf_data_t value, unsigned int size) = 0;
        virtual void rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask);
        virtual ~regfile_dev_subword();
};

class regfile_dev_bitcache : public regfile_dev {
    protected:
        regfile_dev &main_dev;

        struct cache {
            rf_addr_t addr;
            rf_data_t value;
            rf_data_t mask;
            rf_data_t unused_mask;

            bool valid;
        };

        struct cache cache;
        bool cache_enabled;

    protected:
        void cache_flush ();

    public:
        regfile_dev_bitcache (regfile_dev &main);

        virtual rf_data_t rfdev_read  (rf_addr_t addr);
        virtual void      rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask);

        void cache_enable  ();
        void cache_disable ();
};

class regfile_dev_wordcache : public regfile_dev {
    protected:
        regfile_dev &main_dev;

        rf_addr_t *addr_list;
        rf_data_t *value_list;
        rf_data_t *mask_list;
        rf_data_t *unused_mask_list;

        unsigned int seqlen;
        unsigned int seqlen_max;
        bool cache_enabled;

    protected:
        void cache_flush ();

    public:
        regfile_dev_wordcache (regfile_dev &main, unsigned int maxseq);
        virtual ~regfile_dev_wordcache ();

        virtual rf_data_t rfdev_read  (rf_addr_t addr);
        virtual void      rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask);

        void cache_enable  ();
        void cache_disable ();
};

class regfile_dev_debug: public regfile_dev_simple {
    public:
        regfile_dev_debug ();
        virtual rf_data_t rfdev_read (rf_addr_t addr);
        virtual void rfdev_write_simple (rf_addr_t addr, rf_data_t value);
};

class regfile_t {
    protected:
        regfile_dev &_dev;
        rf_addr_t _base_addr;

    protected:
        regfile_t (regfile_dev &dev, rf_addr_t base_addr);

    public:
        rf_data_t _read  (rf_addr_t addr);
        void      _write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask);
        rf_addr_t _get_addr ();
        virtual  ~regfile_t ();
};

class _entry_t {
    public:
        regfile_t &_m_rf;
        rf_addr_t _m_addr;
        rf_data_t _m_unused_mask;

    protected:
        void      _entry_t_write (rf_data_t value);
        rf_data_t _entry_t_read  ();
        rf_addr_t _entry_t_addr  ();

    public:
        _entry_t(regfile_t &rf, rf_addr_t addr, rf_data_t unused_mask);

        _entry_t& operator= (rf_data_t value);
        operator rf_data_t ();
        rf_data_t *operator& ();
};

class _reg_t {
    protected:
        _entry_t &_m_entry;
        unsigned int _m_lsb;
        rf_data_t _m_mask;

        void      _reg_t_write (rf_data_t value);
        rf_data_t _reg_t_read ();

    public:
        _reg_t (_entry_t &entry, unsigned int lsb, unsigned int msb);
};

class _reg_ro_t : public _reg_t {
    public:
        _reg_ro_t (_entry_t &entry, unsigned int lsb, unsigned int msb);

        operator rf_data_t ();
};

class _reg_rw_t : public _reg_t {
    public:
        _reg_rw_t (_entry_t &entry, unsigned int lsb, unsigned int msb);

        _reg_rw_t& operator= (rf_data_t value);
        operator rf_data_t ();
};

class mem_access_t {
    public:
        class value {
            protected:
                mem_access_t &_access;
                uintptr_t     _address;
            public:
                value (mem_access_t &access, uintptr_t address);
                value (value &o);
            public:
                operator rf_data_t ();
                value& operator= (rf_data_t newval);
                value& operator= (value &o);
        };
    protected:
        regfile_dev &_dev;
        rf_addr_t    _base_addr;
        unsigned int _bytes;

    public:
        mem_access_t (regfile_dev &dev, rf_addr_t base_addr);
        mem_access_t (mem_access_t &o);

        mem_access_t& operator= (mem_access_t &o);
        value operator[] (uintptr_t idx);
};

#endif
